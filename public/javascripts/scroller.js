window.addEvent('load', function(){
  var wrap = $E('#scroller .wrap');
  var max_width = window.getWidth()
  var width = $$('#scroller #shoe').length * ($E('#scroller #shoe').getWidth() + 20);
  wrap.setStyle('width', width)
  var repeat = function(){
    var margin = wrap.getStyle('margin-left').toInt()-50;
    if(-margin + 25 > Math.min(max_width, width)) {
      margin = max_width - 50;
      wrap.setStyle('margin-left', max_width)
    }
    tween.start(margin)
  }
  var tween = new Fx.Tween(wrap, 'margin-left', {
    transition:Fx.Transitions.linear,
    fps:55,
    'onComplete': repeat
  });
  repeat();
  wrap.addEvent('mouseenter', function(){
    tween.cancel()
    new Fx.Tween(wrap, 'margin-left', {
      transition: Fx.Transitions.Quad.easeOut
      }).start(wrap.getStyle('margin-left').toInt()-25);
  })
  wrap.addEvent('mouseleave', repeat)
  $$('#scroller img').addEvent('click', function(e){
    new Request.HTML({update:'content', url:'/shoes/'+this.get('rel')}).get()
  })  
})