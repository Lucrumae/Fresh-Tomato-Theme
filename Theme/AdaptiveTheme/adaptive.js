/* bg-video.js — FreshTomato Video Background Injector
   Auto color sampling dari frame pertama video untuk menyesuaikan tema CSS.
   Sample dilakukan sekali saat video mulai play.
*/
(function () {
    var vid = document.createElement('video');
    vid.id = 'bg-video';
    vid.autoplay    = true;
    vid.loop        = true;
    vid.muted       = true;
    vid.playsInline = true;
    vid.setAttribute('playsinline', '');
    vid.crossOrigin = 'anonymous';

    var src = document.createElement('source');
    src.src  = '/bgmp4.gif';
    src.type = 'video/mp4';
    vid.appendChild(src);

    document.body.insertBefore(vid, document.body.firstChild);

    // ---------------------------------------------------------------
    // COLOR SAMPLING — jalan sekali saat video siap diputar
    // ---------------------------------------------------------------
    vid.addEventListener('playing', function onPlay() {
        vid.removeEventListener('playing', onPlay); // hanya sekali

        try {
            // Ambil frame dari tengah video pakai canvas offscreen kecil
            var canvas = document.createElement('canvas');
            canvas.width  = 64; // resolusi kecil = cepat
            canvas.height = 36;
            var ctx = canvas.getContext('2d');
            ctx.drawImage(vid, 0, 0, 64, 36);

            var pixels = ctx.getImageData(0, 0, 64, 36).data;

            // Hitung rata-rata warna dari semua pixel
            var r = 0, g = 0, b = 0, count = 0;
            for (var i = 0; i < pixels.length; i += 4) {
                // Skip pixel yang terlalu gelap atau terlalu terang (tidak representatif)
                var pr = pixels[i], pg = pixels[i+1], pb = pixels[i+2];
                var brightness = (pr + pg + pb) / 3;
                if (brightness < 20 || brightness > 235) continue;
                r += pr; g += pg; b += pb; count++;
            }

            if (count === 0) return; // semua pixel ekstrem, skip

            r = Math.round(r / count);
            g = Math.round(g / count);
            b = Math.round(b / count);

            // Tentukan apakah background terang atau gelap
            var luminance = (0.299 * r + 0.587 * g + 0.114 * b);
            var isDark = luminance < 128;

            // Buat warna aksen dari dominant color (sedikit lebih jenuh)
            var accent = 'rgb(' + r + ',' + g + ',' + b + ')';

            // Panel: kalau bg gelap → panel gelap semi-transparan, sebaliknya terang
            var panelBg, panelEdge, headerBg, textPrimary, textSecondary;

            if (isDark) {
                panelBg     = 'rgba(' + Math.min(r+10,255) + ',' + Math.min(g+10,255) + ',' + Math.min(b+10,255) + ', 0.45)';
                panelEdge   = 'rgba(' + Math.min(r+40,255) + ',' + Math.min(g+40,255) + ',' + Math.min(b+40,255) + ', 0.6)';
                headerBg    = 'rgba(' + Math.max(r-10,0)   + ',' + Math.max(g-10,0)   + ',' + Math.max(b-10,0)   + ', 0.75)';
                textPrimary   = '#f0ece8';
                textSecondary = 'rgba(240,236,232,0.65)';
            } else {
                panelBg     = 'rgba(' + Math.min(r+30,255) + ',' + Math.min(g+30,255) + ',' + Math.min(b+30,255) + ', 0.35)';
                panelEdge   = 'rgba(' + Math.max(r-30,0)   + ',' + Math.max(g-30,0)   + ',' + Math.max(b-30,0)   + ', 0.55)';
                headerBg    = 'rgba(' + Math.max(r-20,0)   + ',' + Math.max(g-20,0)   + ',' + Math.max(b-20,0)   + ', 0.78)';
                textPrimary   = '#1a0a00';
                textSecondary = 'rgba(30,15,0,0.65)';
            }

            // Warna aksen kontras: kalau bg gelap pakai terang, sebaliknya gelap
            var accentContrast = isDark
                ? 'rgb(' + Math.min(r+80,255) + ',' + Math.min(g+80,255) + ',' + Math.min(b+80,255) + ')'
                : 'rgb(' + Math.max(r-80,0)   + ',' + Math.max(g-80,0)   + ',' + Math.max(b-80,0)   + ')';

            // Apply ke CSS variables di :root
            var root = document.documentElement;
            root.style.setProperty('--panel-bg',        panelBg);
            root.style.setProperty('--panel-edge',      panelEdge);
            root.style.setProperty('--header-bg',       headerBg);
            root.style.setProperty('--text-primary',    textPrimary);
            root.style.setProperty('--text-secondary',  textSecondary);
            root.style.setProperty('--accent-auto',     accent);
            root.style.setProperty('--accent-contrast', accentContrast);

        } catch (e) {
            // Canvas gagal (CORS atau browser lama) — diam-diam fallback ke CSS default
        }
    }, { once: true });

})();
