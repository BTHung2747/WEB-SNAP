(function () {
  const root = document.querySelector('[data-prototype]');
  if (!root) return;
  const stateSelect = document.querySelector('[data-state-select]');
  const output = document.querySelector('[data-demo-output]');
  const urlInput = document.querySelector('[data-url]');
  const form = document.querySelector('[data-url-form]');
  const error = document.querySelector('#url-error');
  const allowed = ['idle', 'analyzing', 'video', 'photo', 'queued', 'preparing', 'ready', 'failed', 'cancelled', 'expired'];
  const sampleUrl = 'https://www.youtube.com/watch?v=demo';

  function mediaFigure() {
    return `<figure class="media-frame"><img src="../assets/sample.jpg" alt="Ảnh minh họa gồm bốn khung nhân vật hoạt hình" width="2132" height="2132"><figcaption><span>Ảnh minh họa concept</span><span>Không phải thumbnail nguồn</span></figcaption></figure>`;
  }
  function render(state) {
    root.setAttribute('data-state', state);
    stateSelect.value = state;
    const processing = ['analyzing', 'queued', 'preparing'].includes(state);
    urlInput.disabled = processing;
    document.querySelector('[data-analyze]').disabled = processing;
    document.querySelector('[data-fill]').disabled = processing;
    const commonHead = `<div class="result-head"><div><span class="kicker">Kết quả mẫu</span><h2>Nội dung của bạn</h2></div><span class="sample-flag">Dữ liệu minh họa</span></div>`;
    if (state === 'idle') {
      output.innerHTML = `<div class="empty-state"><span class="empty-index" aria-hidden="true">↙</span><div><h2>Bắt đầu bằng một đường dẫn.</h2><p>Thông tin nội dung và lựa chọn chất lượng sẽ xuất hiện tại đây.</p></div><button type="button" class="text-action" data-next="photo">Khám phá bài ảnh mẫu ↗</button></div>`;
    } else if (state === 'video') {
      output.innerHTML = `${commonHead}<div class="result-grid">${mediaFigure()}<div class="choice-panel"><p class="media-kind">Video mẫu · 00:27</p><h3>Khoảnh khắc trong ngày</h3><label for="quality">Chất lượng từ nguồn</label><select id="quality"><option>MP4 H.264 có tiếng · 720p</option><option>MP4 H.264 có tiếng · 480p</option></select><p class="field-note">Kích thước chưa xác định. Chất lượng trong concept là mẫu.</p><button class="primary-action" type="button" data-next="preparing">Chuẩn bị tệp <span aria-hidden="true">↓</span></button></div></div>`;
    } else if (state === 'photo') {
      output.innerHTML = `${commonHead}<div class="result-grid">${mediaFigure()}<div class="choice-panel"><p class="media-kind">Bài ảnh mẫu · 5 ảnh</p><h3>Chọn một ảnh để tải</h3><label for="photo-choice">Ảnh trong bài</label><select id="photo-choice"><option value="2">Ảnh 2/5 · 2132 × 2132 px</option><option value="1">Ảnh 1/5 · 2132 × 2132 px</option><option value="3">Ảnh 3/5 · 2132 × 2132 px</option><option value="4">Ảnh 4/5 · 2132 × 2132 px</option><option value="5">Ảnh 5/5 · 2132 × 2132 px</option></select><p class="field-note">Một JPG cho ảnh đã chọn. Sau khi chuẩn bị, hãy tạo tác vụ mới nếu muốn chọn ảnh khác.</p><button class="primary-action" type="button" data-next="preparing">Chuẩn bị ảnh 2 <span aria-hidden="true">↓</span></button></div></div>`;
      output.querySelector('#photo-choice').addEventListener('change', (event) => {
        output.querySelector('[data-next]').innerHTML = `Chuẩn bị ảnh ${event.target.value} <span aria-hidden="true">↓</span>`;
      });
    } else if (processing) {
      const text = {
        analyzing: ['Đang phân tích', 'Đang lấy thông tin nội dung.', 'Bạn có thể hủy yêu cầu bất cứ lúc nào.'],
        queued: ['Đang chờ lượt', 'Yêu cầu đang trong hàng đợi.', 'Hệ thống sẽ chuẩn bị khi đến lượt. Không có thời gian chờ giả.'],
        preparing: ['Đang chuẩn bị', 'Tệp đang được xử lý.', 'Bạn có thể hủy yêu cầu. Không cần mở nội dung tài trợ.']
      }[state];
      output.innerHTML = `${commonHead}<div class="status-block preparing-block"><div class="status-mark" aria-hidden="true"></div><div><p class="media-kind">${text[0]}</p><h3>${text[1]}</h3><p>${text[2]}</p></div><button class="text-action" type="button" data-next="cancelled">Hủy yêu cầu</button></div>`;
    } else if (state === 'ready') {
      output.innerHTML = `${commonHead}<div class="status-block ready-block"><div><p class="media-kind">Sẵn sàng mẫu</p><h3>Tệp đã sẵn sàng để tải.</h3><p>Prototype minh họa giao diện. Nút bên cạnh không tạo hoặc tải tệp thật.</p></div><button class="primary-action" type="button" data-demo-download>Tải xuống <span aria-hidden="true">↓</span></button></div><p class="download-feedback field-note" role="status"></p>`;
      output.querySelector('[data-demo-download]').addEventListener('click', () => {
        output.querySelector('.download-feedback').textContent = 'Bạn vừa thử nút mẫu. Khi tích hợp, thao tác này sẽ dùng liên kết tải native từ ứng dụng.';
      });
    } else {
      const text = {
        failed: ['Không thể chuẩn bị', 'Nguồn không phản hồi kịp.', 'Mã mẫu: SOURCE_TIMEOUT. Hãy thử lại sau hoặc dùng một đường dẫn khác.'],
        cancelled: ['Đã hủy', 'Yêu cầu đã được hủy.', 'Bạn có thể phân tích một đường dẫn mới khi sẵn sàng.'],
        expired: ['Đã hết hạn', 'Tệp này không còn khả dụng.', 'Hãy phân tích lại link để tạo tác vụ mới.']
      }[state];
      output.innerHTML = `${commonHead}<div class="status-block failed-block" ${state === 'failed' ? 'role="alert"' : ''}><div><p class="media-kind">${text[0]}</p><h3>${text[1]}</h3><p>${text[2]}</p></div><button class="secondary-action" type="button" data-next="idle">Phân tích link khác</button></div>`;
    }
    output.querySelectorAll('[data-next]').forEach((button) => button.addEventListener('click', () => setState(button.dataset.next, true)));
  }
  function setState(next, moveFocus = false) {
    const state = allowed.includes(next) ? next : 'idle';
    const url = new URL(location.href);
    url.searchParams.set('state', state);
    history.replaceState({}, '', url);
    render(state);
    if (moveFocus) {
      const section = output.parentElement;
      section.focus({ preventScroll: true });
      section.scrollIntoView({ block: 'nearest', behavior: 'auto' });
    }
  }
  stateSelect.addEventListener('change', (event) => setState(event.target.value));
  document.querySelector('[data-fill]').addEventListener('click', () => { urlInput.value = sampleUrl; urlInput.focus(); });
  document.querySelectorAll('[data-demo-state]').forEach((button) => button.addEventListener('click', () => setState(button.dataset.demoState, true)));
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    error.hidden = true;
    let url;
    try { url = new URL(urlInput.value); } catch (_) { error.textContent = 'Hãy nhập đường dẫn hợp lệ.'; error.hidden = false; return; }
    if (!['http:', 'https:'].includes(url.protocol)) { error.textContent = 'Hãy dùng đường dẫn HTTP hoặc HTTPS.'; error.hidden = false; return; }
    setState(url.pathname.includes('/photo/') ? 'photo' : 'video', true);
  });
  setState(new URL(location.href).searchParams.get('state') || 'idle');
})();
