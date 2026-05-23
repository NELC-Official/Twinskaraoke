import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Twinskaraoke",
  description: "iOS, iPadOS and Apple Watch client of www.twinskaraoke.com",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/getting-started' }
    ],

    sidebar: [
      {
        text: 'Installation',
        items: [
          { text: 'Getting Started', link: '/getting-started' },
          { text: 'Build from Source', link: '/build-from-source' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: '//github.com/Evil-Project/Twinskaraoke' }
    ]
  }
})
