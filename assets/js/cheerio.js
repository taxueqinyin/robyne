// cheerio stub - will be replaced with full library
globalThis.__cheerio = {
  load: function(html) {
    return {
      text: function() { return ''; },
      find: function(sel) { return this; },
      attr: function(name) { return ''; },
      each: function(fn) { return this; },
      first: function() { return this; },
      html: function() { return ''; },
    };
  }
};
