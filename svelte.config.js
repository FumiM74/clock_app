import adapter from '@sveltejs/adapter-static';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter(),
    alias: {
      $components: 'src/components',
      // $lib: 'src/lib',
      $routes: 'src/routes'
    }
  }
};

export default config;