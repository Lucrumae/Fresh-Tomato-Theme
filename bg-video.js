/* bg-video.js — FreshTomato Video Background Injector
   File video dinamai bgmp4.gif agar bisa diakses BusyBox httpd.
   Tombol mute/unmute di pojok kanan bawah.
*/
(function () {
    var vid = document.createElement('video');
    vid.id = 'bg-video';
    vid.autoplay    = true;
    vid.loop        = true;
    vid.muted       = true;   // wajib muted agar autoplay jalan
    vid.playsInline = true;
    vid.setAttribute('playsinline', '');

    var src = document.createElement('source');
    src.src  = '/bgmp4.gif';
    src.type = 'video/mp4';
    vid.appendChild(src);

    document.body.insertBefore(vid, document.body.firstChild);

    // Tombol mute/unmute
    var btn = document.createElement('button');
    btn.id = 'bg-mute-btn';
    btn.innerHTML = '🔇';
    btn.title = 'Click to unmute background video';
    btn.style.cssText = [
        'position:fixed',
        'bottom:16px',
        'right:16px',
        'z-index:9999',
        'background:rgba(0,0,0,0.45)',
        'color:#fff',
        'border:1px solid rgba(255,255,255,0.3)',
        'border-radius:50%',
        'width:36px',
        'height:36px',
        'font-size:16px',
        'cursor:pointer',
        'padding:0',
        'line-height:36px',
        'text-align:center',
        'transition:background 0.2s'
    ].join(';');

    btn.addEventListener('mouseover', function () {
        btn.style.background = 'rgba(0,0,0,0.7)';
    });
    btn.addEventListener('mouseout', function () {
        btn.style.background = 'rgba(0,0,0,0.45)';
    });

    btn.addEventListener('click', function () {
        vid.muted = !vid.muted;
        btn.innerHTML = vid.muted ? '🔇' : '🔊';
        btn.title = vid.muted ? 'Click to unmute' : 'Click to mute';
    });

    document.body.appendChild(btn);
})();
