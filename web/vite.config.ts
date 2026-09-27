import { defineConfig } from 'vite'

export default defineConfig({
	base: './',
	build: {
		outDir: 'dist',
		emptyOutDir: true,
		assetsDir: 'assets',
	},
	server: {
		port: 5173,
		strictPort: true,
	},
})
