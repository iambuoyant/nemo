/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
// Builds options for select2 controls so that common options can be reused without duplication.
// It's designed like this, instead of as a wrapper of select2, so it can be used in React as well
// as Backbone.
ELMO.Utils.Select2OptionBuilder = class Select2OptionBuilder {
  ajax(url, resultsKey, textKey) {
    if (resultsKey == null) { resultsKey = 'results'; }
    if (textKey == null) { textKey = 'text'; }
    return {
      url,
      dataType: 'json',
      delay: 250,
      data(params) {
        return {
          search: params.term,
          page: params.page
        };
      },
      processResults(data) {
        const results = data[resultsKey];
        if (textKey !== 'text') { results.forEach(r => r['text'] = r[textKey]); }
        return {results, pagination: {more: data.more}};
      },
      cache: true
    };
  }
};
