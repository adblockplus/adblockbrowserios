export default {
  format: 'iife',
  moduleName: 'api',
  context: 'window',
  banner: "(function() {",
  footer: " return this.api; }).call({})"
};

