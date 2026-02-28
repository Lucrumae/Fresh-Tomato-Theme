(function(){
  var vid = document.getElementById('ft-rbv');
  var ov  = document.getElementById('ft-rbo');
  if(!vid || !ov) return;

  // Adaptive color dari video frame
  var cv = document.createElement('canvas');
  cv.width = 64; cv.height = 36;
  var ctx = cv.getContext('2d');
  var lastHue = -1;

  function H(h,s,l){h/=360;s/=100;l/=100;var q=l<.5?l*(1+s):l+s-l*s,p=2*l-q;function f(t){t<0&&(t+=1);t>1&&(t-=1);return t<1/6?p+(q-p)*6*t:t<.5?q:t<2/3?p+(q-p)*(2/3-t)*6:p;}return[~~(f(h+1/3)*255),~~(f(h)*255),~~(f(h-1/3)*255)];}
  function toHsl(r,g,b){r/=255;g/=255;b/=255;var mx=Math.max(r,g,b),mn=Math.min(r,g,b),h,s,l=(mx+mn)/2;if(mx===mn){h=s=0;}else{var d=mx-mn;s=l>.5?d/(2-mx-mn):d/(mx+mn);h=mx===r?((g-b)/d+(g<b?6:0))/6:mx===g?((b-r)/d+2)/6:((r-g)/d+4)/6;}return[h*360,s*100,l*100];}

  function sample(){
    if(vid.readyState < 2){ setTimeout(sample, 500); return; }
    try{
      ctx.drawImage(vid, 0, 0, 64, 36);
      var px=ctx.getImageData(0,0,64,36).data, r=0,g=0,b=0,n=0;
      for(var i=0;i<px.length;i+=4){
        var br=(px[i]+px[i+1]+px[i+2])/3;
        if(br<15||br>240) continue;
        r+=px[i]; g+=px[i+1]; b+=px[i+2]; n++;
      }
      if(!n){ setTimeout(sample,500); return; }
      r=~~(r/n); g=~~(g/n); b=~~(b/n);
      var hsl=toHsl(r,g,b), hue=hsl[0], sat=hsl[1], lum=hsl[2];
      var d=Math.abs(hue-lastHue); if(d>180) d=360-d;
      if(lastHue<0 || d>=5){
        lastHue=hue;
        var dark=lum<50, s2=Math.max(sat,50);
        var acc=H(hue,Math.max(s2,65),dark?68:42);
        var pan=H(hue,Math.min(s2,40),dark?Math.min(lum+8,20):Math.max(lum-8,80));
        var ovRgb=Math.max(pan[0]-30,0)+','+Math.max(pan[1]-30,0)+','+Math.max(pan[2]-30,0);
        ov.style.background = 'rgba('+ovRgb+',.50)';
        // Update warna accent FreshTomato progress bar & text
        var accStr = 'rgb('+acc[0]+','+acc[1]+','+acc[2]+')';
        document.documentElement.style.setProperty('--accent', accStr);
        // Warnai elemen bawaan FreshTomato (progress bar, teks countdown)
        var inputs = document.querySelectorAll('input[type=text],input[type=button],button');
        inputs.forEach(function(el){
          el.style.backgroundColor = accStr;
          el.style.borderColor = accStr;
        });
      }
    }catch(e){}
    setTimeout(sample, 500);
  }

  vid.addEventListener('canplay', sample, {once:true});
  vid.play().catch(function(){});

  // Pastikan video di bawah konten asli FreshTomato
  // Tapi di atas background hitam
  document.body.style.position = 'relative';
  document.body.style.zIndex   = '2';
  document.body.style.background = 'transparent';
})();
