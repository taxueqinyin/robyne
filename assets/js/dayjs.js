// dayjs stub - minimal implementation for MusicFree plugins
globalThis.__dayjs = function(date) {
  var d = date ? new Date(date) : new Date();
  return {
    format: function(fmt) {
      return d.toISOString();
    },
    valueOf: function() { return d.getTime(); },
    toDate: function() { return d; },
    unix: function() { return Math.floor(d.getTime() / 1000); },
  };
};
