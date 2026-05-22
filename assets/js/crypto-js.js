// crypto-js stub - minimal implementation for MusicFree plugins
globalThis.__cryptoJs = {
  MD5: function(s) { return { toString: function() { return s; } }; },
  SHA1: function(s) { return { toString: function() { return s; } }; },
  SHA256: function(s) { return { toString: function() { return s; } }; },
  HmacSHA256: function(s, key) { return { toString: function() { return s; } }; },
  AES: {
    encrypt: function(text, key, opts) { return { ciphertext: { toString: function() { return text; } } }; },
    decrypt: function(cipher, key, opts) { return { toString: function(enc) { return cipher.toString(); } }; },
  },
  enc: {
    Base64: { stringify: function() { return ''; }, parse: function() { return {}; } },
    Hex: { stringify: function() { return ''; }, parse: function() { return {}; } },
    Utf8: { stringify: function() { return ''; }, parse: function(s) { return s || {}; } },
  },
  mode: { ECB: {}, CBC: {} },
  pad: { Pkcs7: {}, ZeroPadding: {} },
};
