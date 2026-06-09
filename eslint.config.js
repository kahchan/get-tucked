import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['node_modules', 'output'] },
  js.configs.recommended,
  {
    files: ['verifier/**/*.ts'],
    extends: tseslint.configs.recommended,
  },
  {
    files: ['src/**/*.js'],
    languageOptions: {
      globals: {
        window: 'readonly',
        document: 'readonly',
        performance: 'readonly',
        Image: 'readonly',
      },
    },
  },
);
