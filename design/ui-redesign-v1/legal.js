(function () {
  const query = new URLSearchParams(location.search);
  const theme = query.get('theme') === 'b' ? 'b' : 'a';
  document.body.className = `theme-${theme}`;
  document.querySelectorAll('[data-home]').forEach((link) => link.href = `${theme}/index.html`);
  const content = {
    terms: ['Điều khoản sử dụng', 'Quyền sử dụng nội dung', 'Chỉ dùng đường dẫn công khai đến nội dung bạn sở hữu hoặc có quyền tải. Bạn chịu trách nhiệm tôn trọng quyền tác giả và điều khoản của nguồn.'],
    privacy: ['Quyền riêng tư', 'Phiên tải của bạn', 'Cookie HttpOnly giữ quyền sở hữu tác vụ. Chúng tôi lưu metadata tác vụ, trạng thái và số byte cần thiết để xử lý và dọn tệp. Không yêu cầu cookie tài khoản mạng xã hội.'],
    report: ['Báo cáo nội dung', 'Gửi thông tin rõ ràng', 'Gửi URL bài đăng, mô tả vấn đề và bằng chứng quyền sở hữu hoặc quyền đại diện. Không gửi mật khẩu, cookie hay tài liệu chứa secret.']
  };
  const value = content[query.get('page')] || content.terms;
  document.querySelector('[data-legal]').innerHTML = `<p class="eyebrow">Thông tin tham chiếu</p><h1>${value[0]}</h1><section><h2>${value[1]}</h2><p>${value[2]}</p></section><section><h2>Bản concept</h2><p>Đoạn trên trích nguyên văn từ giao diện hiện có. Trang này chỉ giữ đường quay lại và ngôn ngữ trình bày; chưa thay thế toàn bộ trang pháp lý trong ứng dụng.</p></section>`;
})();
