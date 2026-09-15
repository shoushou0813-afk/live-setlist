import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    // テスト対象は UI から切り離した純粋関数だけなので DOM は不要
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
});
