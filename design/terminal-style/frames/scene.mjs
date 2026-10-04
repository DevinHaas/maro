// Editable review composition from native AX coordinates plus pinned source frames.
// Does not run inside Maro and is not application acceptance evidence.
export function buildScene(report) {
  const {width: w, height: h} = report.contentSize;
  const route = report.route;
  const sidebar = w < 1200 ? 280 : 320;
  const mainX = sidebar + 16, mainW = w - sidebar - 24, panelH = h - 172;
  const nodes = [];
  const colors = {abyss:'#0B151A',ocean:'#10232B',lagoon:'#18323B',foam:'#DDF1F0',muted:'#A0BDC4',mint:'#91DAB8',cyan:'#82CDDF',divider:'#2B4A54',control:'#729CA6',selected:'#1D4547'};
  const ax = (text, role) => report.accessibility.find(n => n.text === text && (!role || n.role === role))?.frame;
  const rect = (name,x,y,width,height,fill,radius=0,stroke) => nodes.push({type:'rect',name,x,y,width,height,fill:colors[fill]||fill,radius,stroke:colors[stroke]||stroke});
  const text = (name,value,x,y,width,height,size=12,weight=400,color='foam',native=false) => nodes.push({type:'text',name,text:value,x,y,width,height,size,weight,color:colors[color]||color,font:native?'system':'JetBrains Mono'});
  const label = (name,value,size=12,weight=400,color='foam',native=true,role) => {const b=ax(name,role); if(b) text(name,value,b.x,b.y,b.width,b.height,size,weight,color,native);};
  const art = (name,x,y,width,height,favorites=false) => nodes.push({type:'art',name,x,y,width,height,radius:5,favorites});
  const icon = (name,symbol,b,fill='foam',background) => {if(b)nodes.push({type:'icon',name,symbol,...b,color:colors[fill]||fill,background:colors[background]||background});};
  rect('Canvas',0,0,w,h,'abyss');
  rect('Library panel',8,72,sidebar,panelH,'ocean',8,'divider');
  rect('Content panel',mainX,72,mainW,panelH,'ocean',8,'divider');
  label('maro','maro',24,800,'foam',true);
  icon('Back','back',ax('Back'),'muted'); icon('Hide library','sidebar',ax('Hide library'));
  icon('Home','home',ax('Home'),'foam','lagoon');
  const searchImage = ax('Search','AXImage');
  const field = report.accessibility.find(n => n.role === 'AXTextField' && n.text !== 'Filter your library')?.frame;
  if(searchImage && field) {
    const sx=searchImage.x-18, sw=field.x+field.width+18-sx;
    rect('Global search',sx,10,sw,44,'lagoon',22,'control');
    icon('Search','search',searchImage,'muted');
    text('Native search field','What do you want to play?',field.x,field.y,field.width,field.height,14,400,'muted',true);
  }
  icon('YouTube account','account',ax('YouTube account'),'mint');
  label('Your Library','▥  Your Library',15,700,'foam',true);
  icon('Create playlist','plus',ax('Create playlist')); icon('Refresh library','refresh',ax('Refresh library'));
  rect('Library filter',20,130,sidebar-24,36,'lagoon',18,'control');
  icon('Library search','search',{x:31.5,y:141.5,width:12.5,height:13},'muted');
  const filter=ax('Filter your library'); if(filter)text('Library filter field','Search your library',filter.x,filter.y,filter.width,filter.height,13,400,'muted',true);
  const playlists=['Favorites','Late night jazz','Lofi focus','Electronic discoveries','Quiet afternoons','Piano favourites','Ambient journeys','Weekend listening','Café classics'];
  playlists.forEach((title,i)=>{
    const y=178+i*68; if(y+66>72+panelH-45)return;
    const selected=route==='playlist'||route==='rows';
    if(selected&&i===1)rect('Selected playlist',14,y,sidebar-12,66,'selected',6);
    art('Library artwork '+i,22,y+8,50,50,i===0);
    text('Library title '+i,title,84,y+16,sidebar-84,18,14,500,selected&&i===1?'mint':'foam');
    text('Library metadata '+i,i===0?'Saved on this Mac':'Playlist · Local acceptance fixture · 40 videos',84,y+39,sidebar-84,15,11,400,'muted');
  });
  const libraryStatus=report.accessibility.find(n=>n.role==='AXStaticText'&&n.frame.x===24&&n.frame.y>h-180&&n.frame.width<sidebar);
  if(libraryStatus)text('Library status',libraryStatus.text,libraryStatus.frame.x,libraryStatus.frame.y,libraryStatus.frame.width,libraryStatus.frame.height,10,400,'muted',true);
  if(route==='home'||route==='preview') {
    const x=mainX+24, y=96, heroW=mainW-48;
    rect('Home feature',x,y,heroW,260,'lagoon',8);
    art('Home feature artwork',x,y,Math.max(160,heroW*.43),260);
    label('FROM YOUR LIBRARY','FROM YOUR LIBRARY',10,700,'muted',true);
    label('Late night jazz','Late night jazz',heroW<650?26:34,700,'foam',true,'AXStaticText');
    label('A collection for unhurried listening.','A collection for unhurried listening.',12,400,'muted',true);
    const open=ax('Open playlist'); if(open){rect('Open playlist control',open.x,open.y,open.width,open.height,'mint',19);text('Open playlist label','Open playlist',open.x+18,open.y+11,open.width-36,16,13,700,'abyss',true);}
    const cols=Math.floor((heroW+10)/228), cell=(heroW-(cols-1)*10)/cols;
    playlists.slice(0,8).forEach((title,i)=>{
      const cx=x+(i%cols)*(cell+10),cy=380+Math.floor(i/cols)*72;
      rect('Shortcut '+i,cx,cy,cell,62,'lagoon',5); art('Shortcut artwork '+i,cx,cy,62,62,i===0);
      text('Shortcut title '+i,title,cx+74,cy+21,cell-128,32,13,700,'foam',true);
      icon('Shortcut play '+i,'play',{x:cx+cell-46,y:cy+12,width:38,height:38},'abyss','mint');
    });
    label('Because you saved jazz videos','Because you saved jazz videos',12,400,'muted',true);
    label('Jazz','Jazz',23,700,'foam',true); label('Search jazz','Explore',12,600,'muted',true);
    const cardTop=report.accessibility.find(n=>n.text==='Play Quiet sessions 2 by Jazz collective'&&n.frame.width===176)?.frame.y;
    if(cardTop)for(let i=0;i<6;i++){
      const cx=x+10+i*210; if(cx>=w)break;
      art('Recommendation artwork '+i,cx,cardTop,176,176);
      text('Recommendation title '+i,'Quiet sessions '+(i+2),cx,cardTop+186,176,36,14,600);
      text('Recommendation artist '+i,i<2?'Jazz collective':'Creator '+(i+2),cx,cardTop+232,176,15,12,400,'muted');
    }
  } else if(route==='playlist'||route==='rows') {
    art('Playlist original full-color cover',mainX,72,mainW,320);
    rect('Cover readability veil',mainX,72,mainW,320,'#0B151A99');
    label('Private playlist','Private playlist',12,500,'foam',true);
    label('Late night jazz','Late night jazz',54,800,'foam',true,'AXHeading');
    label('A collection for unhurried listening.','A collection for unhurried listening.',13,400,'foam',true);
    label('Local acceptance fixture · 40 videos','Local acceptance fixture · 40 videos',12,500,'foam',true);
    const pb=report.accessibility.find(n=>n.text==='Play Late night jazz in saved order'&&n.frame.width===62)?.frame;
    icon('Playlist play','play',pb,'abyss','mint');icon('Playlist actions','more',ax('Playlist actions for Late night jazz'));
    label('Saved order','Saved order',12,400,'muted',true);
    const rowTop=report.accessibility.find(n=>n.text.startsWith('Reorder 1.'))?.frame.y;
    if(rowTop)for(let i=0;i<5;i++){
      const y=rowTop+i*60; if(y+44>72+panelH)break;
      if(route==='rows'&&i===1)rect('Active occurrence',mainX+24,y-7,mainW-48,58,'selected',5);
      icon('Drag handle '+i,'drag',{x:mainX+32,y,width:16,height:44},'muted');
      text('Row index '+i,String(i+1),mainX+62,y+13,24,15,12,400,'muted',true);
      art('Track artwork '+i,mainX+100,y,44,44);
      text('Track title '+i,i===3?'Deleted video':`${i+1}. Midnight jazz sessions — a long title to test row layout`,mainX+158,y+4,Math.max(120,mainW-510),18,14,500,i===1&&route==='rows'?'mint':'foam');
      text('Track creator '+i,i===3?'Unavailable':'Jazz collective',mainX+158,y+26,Math.max(120,mainW-510),15,11,400,'muted');
      text('Row date '+i,'1 Oct 2026',w-192,y+15,100,14,11,400,'muted',true);
      icon('Row actions '+i,'more',{x:w-78,y:y+3,width:38,height:38});
    }
    text('Playlist columns','Title',mainX+124,(rowTop||545)-42,400,14,11,400,'muted',true);
  } else if(route==='results') {
    label('Results for “jazz”','Results for “jazz”',28,700,'foam',true);
    label('TITLE','TITLE',10,700,'muted',true); label('DURATION','DURATION',10,700,'muted',true);
    for(let i=0;i<5;i++) {
      const y=201+i*68;
      icon('Result play '+i,'play',{x:mainX+36,y:y+7,width:38,height:38},'foam');
      art('Result artwork '+i,mainX+86,y,52,52);
      text('Result title '+i,i===0?'Midnight jazz — a very long title to verify truncation and full accessibility labels':'Quiet sessions '+(i+1),mainX+150,y+8,mainW-360,18,14,500);
      text('Result creator '+i,i<4?'Jazz collective':'Creator '+i,mainX+150,y+31,mainW-360,15,12,400,'muted');
      text('Result duration '+i,'5:00',w-180,y+19,60,15,12,400,'muted',true);
      icon('Result favorite '+i,'heart',{x:w-127,y:y+7,width:38,height:38},i===0?'mint':'foam');
      icon('Result actions '+i,'more',{x:w-77,y:y+7,width:38,height:38});
    }
    label('Load 5 more','Load 5 more',13,400,'foam',true);
  }
  // Opaque chrome owns the player and clips scroll content at the native panel.
  rect('Player canvas',0,h-100,w,100,'abyss');
  art('Player artwork',20,h-76,56,56);
  const playerText=report.accessibility.filter(n=>n.role==='AXStaticText'&&n.frame.x===88&&n.frame.y>h-88);
  playerText.forEach((n,i)=>text(i===0?'Player title':'Player creator',n.text,n.frame.x,n.frame.y,n.frame.width,n.frame.height,i===0?12:10,i===0?500:400,i===0?'foam':'muted',true));
  for(const [name,symbol,fill,bg] of [['Toggle favorite','heart','foam'],['Previous','previous','muted'],['Play','play','abyss','mint'],['Pause','pause','abyss','mint'],['Next','next','muted'],['Add to playlist','plus','foam']])icon(name,symbol,ax(name),fill,bg);
  report.accessibility.filter(n=>n.role==='AXStaticText'&&n.frame.y>h-50&&/^\d+:\d+$/.test(n.text)).forEach(n=>text('Player time '+n.text,n.text,n.frame.x,n.frame.y,n.frame.width,n.frame.height,10,400,'muted',true));
  const timeline=report.accessibility.find(n=>n.role==='AXSlider'&&n.text==='')?.frame;
  if(timeline){rect('Timeline rail',timeline.x,timeline.y+7,timeline.width,3,'control',2);rect('Timeline progress',timeline.x,timeline.y+7,timeline.width*38/300,3,'mint',2);}
  const volume=ax('Playback volume'); if(volume){rect('Volume rail',volume.x,volume.y+7,volume.width,3,'control',2);icon('Volume','volume',{x:volume.x-28,y:volume.y,width:18,height:18},'muted');}
  if(route==='preview'&&searchImage&&field) {
    const px=searchImage.x-18,pw=field.x+field.width+18-px;
    rect('Search preview opaque overlay',px,62,pw,520,'lagoon',8,'control');
    text('Preview navigation','↕ Navigate',px+16,79,140,13,10,400,'muted',true);
    text('Preview keyboard hint','Return to search',px+pw-130,79,112,13,10,400,'muted',true);
    ['jazz','ambient','electronic','lofi music'].forEach((q,i)=>{icon('Preview query icon '+i,'search',{x:px+28,y:112+i*39,width:18,height:18},'muted');text('Preview query '+i,q,px+72,112+i*39,pw-110,18,13,400,'foam',true);});
    text('Preview section','PICK UP WHERE YOU LEFT OFF',px+18,282,pw-36,13,10,700,'muted',true);
    for(let i=0;i<3;i++){const y=310+i*66;art('Preview artwork '+i,px+16,y,48,48);text('Preview title '+i,i===0?'Midnight jazz — a very long title to verify truncation':'Quiet sessions '+(i+1),px+76,y+7,pw-176,16,13,600);text('Preview creator '+i,'Jazz collective',px+76,y+28,pw-176,14,11,400,'muted');icon('Preview favorite '+i,'heart',{x:px+pw-84,y:y+5,width:38,height:38});icon('Preview add '+i,'plus',{x:px+pw-44,y:y+5,width:38,height:38});}
  }
  return {name:`Tidal review v1 · ${route} · ${w}×${h}`,width:w,height:h,route,nodes,limits:'Editable styling proposal. AX-linked controls are native measured; unexposed decorative/content bounds are pinned-source reconstructions. JetBrains fixed-container candidates need native baseline validation. Intrinsic headings/navigation/search/button fonts retain SF pending proof.'};
}

export const iconPaths = {
  play:'M8 5L20 12L8 19Z',pause:'M8 5V19M16 5V19',back:'M15 5L8 12L15 19',sidebar:'M4 5H20V19H4ZM9 5V19',home:'M3 11L12 3L21 11M6 9V21H18V9M10 21V14H14V21',
  search:'M10 3A7 7 0 1 0 10 17A7 7 0 1 0 10 3M15 15L21 21',plus:'M12 4V20M4 12H20',refresh:'M20 7A9 9 0 1 0 21 13M20 3V8H15',heart:'M12 20L3 11C-1 2 8 0 12 6C16 0 25 2 21 11Z',
  more:'M5 12H5.1M12 12H12.1M19 12H19.1',drag:'M8 5H8.1M16 5H16.1M8 12H8.1M16 12H16.1M8 19H8.1M16 19H16.1',previous:'M5 5V19M19 5L7 12L19 19Z',next:'M19 5V19M5 5L17 12L5 19Z',account:'M12 2A10 10 0 1 0 12 22A10 10 0 1 0 12 2M12 6A3 3 0 1 0 12 12A3 3 0 1 0 12 6M5 19Q12 12 19 19',volume:'M3 9H7L12 5V19L7 15H3ZM16 8Q21 12 16 16'
};
