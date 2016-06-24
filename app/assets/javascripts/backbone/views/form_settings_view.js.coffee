class ELMO.Views.FormSettingsView extends Backbone.View
  el: 'form.form_form'

  events:
    'click .more-settings': 'show_setting_fields'
    'click .less-settings': 'hide_setting_fields'
    'click #form_smsable': 'show_hide_sms_settings'
    'click #form_sms_relay': 'show_hide_sms_forwardees'

  initialize: (options) ->
    @show_fields_with_errors()
    @show_hide_sms_settings()
    @show_hide_sms_forwardees()
    @forwardee_options_url = options.forwardee_options_url
    @init_sms_forwardee_select()

  show_setting_fields: (event) ->
    event.preventDefault()
    $('.more-settings').hide()
    $('.less-settings').show()
    $('.setting-fields').show()

  hide_setting_fields: (event) ->
    event.preventDefault()
    $('.more-settings').show()
    $('.less-settings').hide()
    $('.setting-fields').hide()

  show_fields_with_errors: ->
    $('.field_with_errors:hidden').closest('.setting-fields').show()

  show_hide_sms_settings: ->
    m = if @$('#form_smsable').is(':checked') then 'show' else 'hide'
    @$('.sms-fields')[m]()

  show_hide_sms_forwardees: ->
    m = if @$('#form_sms_relay').is(':checked') then 'show' else 'hide'
    @$('.form_sms_forwardee_ids')[m]()

  init_sms_forwardee_select: ->
    @$('#form_sms_forwardee_ids').select2
      ajax:
        url: @forwardee_options_url
        dataType: 'json'
        delay: 250
        cache: true
        processResults: (data) -> {results: data}
