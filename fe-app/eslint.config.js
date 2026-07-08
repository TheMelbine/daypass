// eslint.config.js — flat config, adapted from fe-app-podkop.
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import prettier from 'eslint-config-prettier';

export default [
    js.configs.recommended,
    ...tseslint.configs.recommended,
    {
        ignores: ['node_modules', 'dist', 'watch-upload.js'],
    },
    {
        languageOptions: {
            globals: {
                // LuCI runtime globals (injected by the module loader).
                _: 'readonly',
                L: 'readonly',
                E: 'readonly',
                baseclass: 'readonly',
                dom: 'readonly',
                ui: 'readonly',
                uci: 'readonly',
                rpc: 'readonly',
                fs: 'readonly',
                poll: 'readonly',
                window: 'readonly',
                document: 'readonly',
                WebSocket: 'readonly',
                MutationObserver: 'readonly',
                setTimeout: 'readonly',
                clearTimeout: 'readonly',
                setInterval: 'readonly',
                clearInterval: 'readonly',
                structuredClone: 'writable',
                globalThis: 'readonly',
            },
        },
        rules: {
            'no-console': 'off',
            'no-unused-vars': 'off',
            '@typescript-eslint/no-unused-vars': [
                'warn',
                {
                    argsIgnorePattern: '^_',
                    varsIgnorePattern: '^_',
                    caughtErrorsIgnorePattern: '^_',
                },
            ],
        },
    },
    prettier,
];
