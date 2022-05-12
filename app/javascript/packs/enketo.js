import { Form } from 'enketo-core';

// The XSL transformation result contains a HTML Form and XML instance.
// These can be obtained dynamically on the client, or at the server/
// In this example we assume the HTML was injected at the server and modelStr
// was injected as a global variable inside a <script> tag.

async function inject() {
  // required HTML Form DOM element
  const formEl = document.querySelector('#enketo form');

  // required object containing data for the form
  const data = {
    // required string of the default instance defined in the XForm
    modelStr: window.ENKETO_MODEL_STR,
    // optional string of an existing instance to be edited
    instanceStr: window.ENKETO_INSTANCE_STR,
    // optional boolean whether this instance has ever been submitted before
    submitted: false,
    // optional array of external data objects containing:
    // {id: 'someInstanceId', xml: XMLDocument}
    external: [],
    // optional object of session properties
    // 'deviceid', 'username', 'email', 'phonenumber', 'simserial', 'subscriberid'
    session: {},
  };

  // Form-specific configuration
  const options = {};

  // Instantiate a form
  const form = new Form(formEl, data, options);

  // Initialize the form and capture any load errors
  // TODO: Handle loadErrors
  const loadErrors = form.init();
  console.error({ loadErrors });

  // If desired, scroll to a specific question with any XPath location expression,
  // and aggregate any loadErrors.
  // loadErrors = loadErrors.concat(form.goTo('//repeat[3]/node'));

  $('#enketo-submit').on('click', async () => {
    // clear non-relevant questions and validate
    const valid = await form.validate();

    if (!valid) {
      // TODO: Convert to DOM element
      alert('Form contains errors. Please see fields marked in red.');
    } else {
      // Record is valid!
      ELMO.app.loading(true);

      // Convert into a file to upload, like NEMO expects from Collect;
      // adapted from https://stackoverflow.com/a/34340245/763231.
      const xml = form.getDataStr();
      const formData = new FormData();
      formData.append('xml_submission_file', new File([new Blob([xml])], 'submission.xml'));

      const editingResponse = $('#enketo-submit').data('responseShortcode');

      $.ajax({
        url: submissionUrl(editingResponse),
        method: editingResponse ? 'put' : 'post',
        data: formData,
        processData: false,
        contentType: false,
        success: (_data, _status, { status, statusText, responseJSON }) => {
          // These will be empty on NEW submission, but present on EDIT.
          const { msg, redirect } = responseJSON || {};

          // TODO: How to flash this success msg?
          console.log({ status, statusText, msg });

          window.location.href = redirect || ELMO.app.url_builder.build('responses');
        },
        error: ({ status, statusText, responseJSON }) => {
          // TODO: Convert to DOM element
          alert(`Error submitting form: ${status} ${statusText}`);

          // TODO: How to flash this error msg?
          console.log({ error: responseJSON.error });
        },
        always: () => {
          ELMO.app.loading(false);
        },
      });
    }
  });
}

function submissionUrl(editingResponse) {
  const base = editingResponse
    ? ELMO.app.url_builder.build('submission', editingResponse)
    : ELMO.app.url_builder.build('submission');
  return `${base}?enketo=1`;
}

// Run the async method.
inject();
