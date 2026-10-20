import UrlPattern from 'url-pattern';
export const services = {
    tiktok: {
        patterns: [
            ":user/video/:postId",
            "i18n/share/video/:postId",
            ":shortLink",
            "t/:shortLink",
            ":user/photo/:postId",
            "v/:postId.html"
        ],
        subdomains: ["vt", "vm", "m", "t", "pro"],
    },
};
Object.values(services).forEach(service => {
    service.patterns = service.patterns.map(
        pattern => new UrlPattern(pattern, {
            segmentValueCharset: UrlPattern.defaultOptions.segmentValueCharset + '@\\.:'
        })
    )
})
