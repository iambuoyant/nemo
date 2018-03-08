# frozen_string_literal: true

# Stores and manages settings per-mission and admin mode.
class Setting < ApplicationRecord
  include MissionBased

  # Attribs to copy to configatron
  KEYS_TO_COPY = %w[timezone preferred_locales all_locales incoming_sms_numbers frontlinecloud_api_key
                    twilio_phone_number twilio_account_sid twilio_auth_token theme].freeze

  # These are the keys that make sense in admin mode
  ADMIN_MODE_KEYS = %w[timezone preferred_locales theme universal_sms_token].freeze

  DEFAULT_TIMEZONE = "UTC"

  # The user-provided theme file is copied into this path by the preprocessor. If it's there
  # we know we're ready to display the theme.
  THEME_SCSS_PATH = "app/assets/stylesheets/all/themes/_custom.scss"

  before_validation(:normalize_locales)
  before_validation(:normalize_incoming_sms_numbers)
  before_validation(:nullify_fields_if_these_are_admin_mode_settings)
  before_validation(:normalize_twilio_phone_number)
  before_validation(:clear_sms_fields_if_requested)
  validate(:locales_are_valid)
  validate(:one_locale_must_have_translations)
  validate(:sms_adapter_is_valid)
  validate(:sms_credentials_are_valid)
  before_save(:save_sms_credentials)

  serialize :preferred_locales, JSON
  serialize :incoming_sms_numbers, JSON

  # accessors for password/password confirm/clear fields
  attr_accessor :twilio_auth_token1, :frontlinecloud_api_key1, :clear_twilio, :clear_frontlinecloud

  # loads the settings for the given mission (or nil mission/admin mode) into the configatron store
  # if the settings can't be found, a default setting is created and saved before being loaded
  def self.load_for_mission(mission)
    unless (setting = find_by(mission: mission))
      setting = build_default(mission)
      setting.save!
    end
    setting.load
    setting
  end

  # loads the default settings without saving
  def self.load_default
    setting = build_default
    setting.load
    setting
  end

  # May return nil if it hasn't been created yet.
  # Admin mode setting gets created via load_for_mission when admin mode first loaded.
  def self.admin_mode_setting
    find_by(mission: nil)
  end

  # Builds and returns (but doesn't save) a default Setting object
  # by using defaults specified here and those specified in the local config
  # mission may be nil.
  def self.build_default(mission = nil)
    setting = new(mission: mission)
    setting.timezone = DEFAULT_TIMEZONE
    setting.preferred_locales = [:en]
    setting.incoming_sms_numbers = []
    setting.generate_incoming_sms_token if mission.present?
    if (admin_mode_theme = admin_mode_setting.try(:theme))
      setting.theme = admin_mode_theme
    end
    copy_default_settings_from_configatron_to(setting)
    setting
  end

  def self.copy_default_settings_from_configatron_to(setting)
    configatron.default_settings.configatron_keys.each do |k|
      setting.send("#{k}=", configatron.default_settings.send(k)) if setting.respond_to?("#{k}=")
    end
  end

  def self.theme_exists?
    File.exist?(Rails.root.join(THEME_SCSS_PATH))
  end

  def self.theme_options
    [%w[NEMO nemo], %w[ELMO elmo], [I18n.t("common.custom"), "custom"]]
  end

  def generate_override_code!(size = 6)
    self.override_code = Random.alphanum_no_zero(size)
    save!
  end

  def universal_sms_token
    configatron.key?(:universal_sms_token) ? configatron.universal_sms_token : nil
  end

  def generate_incoming_sms_token(replace = false)
    # Don't replace token unless replace==true
    return unless incoming_sms_token.nil? || replace

    # Ensure that the new token is actually different
    new_token = nil
    loop do
      new_token = SecureRandom.hex
      break unless new_token == incoming_sms_token
    end

    self.incoming_sms_token = new_token
  end

  def regenerate_incoming_sms_token!
    generate_incoming_sms_token(true)
    save!
  end

  # copies this setting to configatron
  def load
    # build hash
    hsh = Hash[*KEYS_TO_COPY.flat_map { |k| [k.to_sym, send(k)] }]

    # get class based on sms adapter setting; default to nil if setting is invalid
    hsh[:outgoing_sms_adapter] = begin
      Sms::Adapters::Factory.instance.create(default_outgoing_sms_adapter)
    rescue ArgumentError
      nil
    end

    # set the preferred locale for the mission
    hsh[:preferred_locale] = preferred_locales.first

    # set system timezone
    Time.zone = timezone

    # copy to configatron
    configatron.configure_from_hash(hsh)
  end

  # converts preferred_locales to a comma delimited string
  def preferred_locales_str
    (preferred_locales || []).join(",")
  end

  def preferred_locales_str=(codes)
    self.preferred_locales = (codes || "").split(",")
  end

  # converts preferred locales to symbols on read
  def preferred_locales
    self["preferred_locales"].map(&:to_sym)
  end

  # union of system locales with the mission's user-defined locales
  def all_locales
    configatron.full_locales | preferred_locales
  end

  def default_locale
    preferred_locales.first
  end

  def incoming_sms_numbers_str
    incoming_sms_numbers.join(", ")
  end

  def incoming_sms_numbers_str=(nums)
    self.incoming_sms_numbers = (nums || "").split(",").map { |n| PhoneNormalizer.normalize(n) }.compact
  end

  # Determines if this setting is read only due to mission being locked.
  def read_only?
    mission.try(:locked?) # Mission may be nil if admin mode, in which case it's not read only.
  end

  private

  # gets rid of any junk chars in locales
  def normalize_locales
    self.preferred_locales = preferred_locales.map { |l| l.to_s.downcase.gsub(/[^a-z]/, "")[0, 2] }
    true
  end

  def normalize_twilio_phone_number
    # Allow for the use of a database that hasn't had the migration run
    return unless respond_to?(:twilio_phone_number)

    self.twilio_phone_number = PhoneNormalizer.normalize(twilio_phone_number)
  end

  def normalize_incoming_sms_numbers
    # Most normalization is performed in the assignment method.
    # Here we just ensure no nulls.
    self.incoming_sms_numbers = [] if incoming_sms_numbers.blank?
  end

  # makes sure all language codes are valid ISO639 codes
  def locales_are_valid
    preferred_locales.each do |l|
      errors.add(:preferred_locales_str, :invalid_code, code: l) unless ISO_639.find(l.to_s)
    end
  end

  # makes sure at least one of the chosen locales is an available locale
  def one_locale_must_have_translations
    return unless (preferred_locales & configatron.full_locales).empty?
    errors.add(:preferred_locales_str, :one_must_have_translations,
      locales: configatron.full_locales.join(","))
  end

  # sms adapter can be blank or must be valid according to the Factory
  def sms_adapter_is_valid
    errors.add(:default_outgoing_sms_adapter, :is_invalid) unless default_outgoing_sms_adapter.blank? ||
        Sms::Adapters::Factory.name_is_valid?(default_outgoing_sms_adapter)
  end

  # check if settings for a particular adapter should be validated
  def should_validate?(adapter)
    # settings for the default outgoing adapter should always be validated
    return true if default_outgoing_sms_adapter == adapter

    # settings for an adapter should be validated if any settings for that adapter are present
    case adapter
    when "Twilio"
      twilio_phone_number.present? || twilio_account_sid.present? || twilio_auth_token1.present?
    when "FrontlineCloud"
      frontlinecloud_api_key.present?
    end
  end

  # checks that the provided credentials are valid
  def sms_credentials_are_valid
    validate_twilio if should_validate?("Twilio")
    validate_frontline_cloud if should_validate?("FrontlineCloud")
  end

  def validate_twilio
    errors.add(:twilio_account_sid, :blank) if twilio_account_sid.blank?
    errors.add(:twilio_auth_token1, :blank) if twilio_auth_token.blank? && twilio_auth_token1.blank?
  end

  def validate_frontline_cloud
    return unless frontlinecloud_api_key.blank? && frontlinecloud_api_key1.blank?
    errors.add(:frontlinecloud_api_key1, :blank)
  end

  # clear SMS fields if requested
  def clear_sms_fields_if_requested
    if clear_twilio == "1"
      self.twilio_phone_number = nil
      self.twilio_account_sid = nil
      self.twilio_auth_token = nil
      self.twilio_auth_token1 = nil
    end
    self.frontlinecloud_api_key = nil if clear_frontlinecloud == "1"
  end

  # if the sms credentials temp fields are set (and they match, which is checked above),
  # copy the value to the real field
  def save_sms_credentials
    self.twilio_auth_token = twilio_auth_token1 if twilio_auth_token1.present?
    self.frontlinecloud_api_key = frontlinecloud_api_key1 if frontlinecloud_api_key1.present?
    true
  end

  # if we are in admin mode, then a bunch of fields don't make sense and should be null
  # make sure they are in fact null
  def nullify_fields_if_these_are_admin_mode_settings
    # if mission_id is nil, that means we're in admin mode
    return if mission_id.present?
    (attributes.keys - ADMIN_MODE_KEYS - %w[id created_at updated_at mission_id]).each do |a|
      send("#{a}=", nil)
    end
  end
end
