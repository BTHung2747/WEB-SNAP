const direction = new URLSearchParams(location.search).get('theme') === 'b' ? 'b' : 'a';
document.querySelector('iframe').src = `${direction}/index.html`;
document.querySelector('#direct').href = `${direction}/index.html`;
document.querySelector('#title').textContent = `Hướng ${direction.toUpperCase()} · Mobile`;
document.querySelector('#width').addEventListener('change', (event) => {
  document.querySelector('.device').style.width = `min(${event.target.value}px,100%)`;
});
