import { build } from 'esbuild';

await build({
  entryPoints: ['tool/vendor_entry.js'],
  bundle: true,
  platform: 'browser',
  format: 'iife',
  globalName: '__robyneVendorBundle',
  outfile: 'assets/js/musicfree_vendor.js',
  logLevel: 'info',
});
