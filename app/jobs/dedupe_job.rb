# frozen_string_literal: true

# Removes duplicate stragglers
class DedupeJob < ApplicationJob
  TMP_DUPE_BACKUPS_PATH = Rails.root.join("tmp/odk_dupes_backup")

  def perform
    dupe_codes = find_dupe_codes
    backup_duplicate_xml(dupe_codes)
    destroy_duplicates!(dupe_codes)
    clean_up
  end

  private

  def find_dupe_codes
    # Make hashtable with checksum as key, reject sets where there is only 1
    puts "dirty attachment tuples #{dirty_attachment_tuples}"
    puts "all potential dupes: #{all_potential_dupes}"
    dupe_checksum_tuples = all_potential_dupes.group_by { |t| t[3] }.values.reject { |set| set.size < 2 }
    # puts "dupe checksum tuples: #{dupe_checksum_tuples}"
    ensure_unique_users(dupe_checksum_tuples)
  end

  def ensure_unique_users(dupe_checksum_tuples)
    dupe_checksum_tuples.map do |dc|
      # Build hash table with user key (need unique users)
      user_sets = dc.group_by { |t| t[2] }.values.reject { |set| set.size < 2 }
      # Get the sets that were submitted later and only get the code
      user_sets.map { |set| set[1..].map { |t| t[0] } }.flatten
    end.flatten
  end

  def all_potential_dupes
    check_clean_checksums(dirty_attachment_tuples)
  end

  def dirty_attachment_tuples
    ActiveStorage::Attachment.where(record_id: Response.dirty_dupe.map(&:id))
      .where(record_type: "Response")
      .includes(record: :user)
      .order(created_at: :desc)
      .filter { |attachment| attachment.record.presence }.map do |attachment|
      response = attachment.record
      [response.shortcode, response.created_at, response.user.name, attachment.checksum, response.mission_id]
    end.compact
  end

  def check_clean_checksums(dirty_tuples)
    clean_and_dirty_tuples = []
    dirty_tuples.each do |dt|
      clean_and_dirty_tuples << dt
      dupe = dupe_response_for_checksum(dt[3])
      next if dupe.nil?
      clean_and_dirty_tuples << dupe
    end
    clean_and_dirty_tuples
  end

  def dupe_response_for_checksum(checksum)
    # we only need to check if one matches
    blobs = ActiveStorage::Blob.where(checksum: checksum)
    blobs.each do |blob|
      # iterate each blob and see if there is a response, since we could have hanging blobs/attachments with no resposne
    end


    puts "Found some blobs!"
    attachment = ActiveStorage::Attachment.where(blob_id: blob.id).first
    return if attachment.nil?
    puts "found the attachment! looking for response with id: #{attachment.record_id}"
    response = Response.where(id: attachment.record_id, dirty_dupe: false)
    return if response.nil?
    puts "foudn the response!"

    [response.shortcode, response.created_at, response.user.name, attachment.checksum, response.mission_id]
  end

  def backup_duplicate_xml(dupe_codes)
    # see submission error, save to tmp/duplicates
    dupe_responses = Response.where(shortcode: dupe_codes).map(&:id)
    attachments = ActiveStorage::Attachment.where(record_id: dupe_responses)
    FileUtils.mkdir_p(TMP_DUPE_BACKUPS_PATH)
    attachments.each do |a|
      copy_attachment(a)
    end
  end

  def copy_attachment(attachment)
    File.open("#{TMP_DUPE_BACKUPS_PATH}/#{attachment.filename}", "w") do |f|
      attachment.download { |chunk| f.write(chunk) }
    end
  end

  def destroy_duplicates!(dupe_codes)
    ResponseDestroyer.new(scope: Response.where(shortcode: dupe_codes)).destroy!
  end

  def clean_up
    Response.dirty_dupe.update_all(dirty_dupe: false)
  end
end
