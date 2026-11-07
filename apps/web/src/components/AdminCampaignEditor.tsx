import { useState, type FormEvent, type Ref } from 'react';
import { AdCreative } from './Advertising';
import Icon from './Icon';

export const placements = {
  banner: { name: 'Banner trang chủ', detail: 'Nằm dưới khu vực dán liên kết.' },
  sponsor: { name: 'Tài trợ khi chuẩn bị MP4', detail: 'Nằm cạnh thông tin tệp trong lúc chờ hoặc chuẩn bị MP4.' },
};

export type CampaignDraft = {
  id?: string;
  title: string;
  targetUrl: string;
  imageUrl: string;
  placement: keyof typeof placements;
  linkType: 'sponsored' | 'affiliate';
  startsAt: string;
  endsAt: string;
  weight: number;
  enabled: boolean;
};

function localDate(iso: string) {
  const date = new Date(iso);
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
}

export default function AdminCampaignEditor({ draft, update, save, close, busy, titleInput }: {
  draft: CampaignDraft;
  update: (draft: CampaignDraft) => void;
  save: (event: FormEvent<HTMLFormElement>) => void;
  close: () => void;
  busy: boolean;
  titleInput: Ref<HTMLInputElement>;
}) {
  const [image, setImage] = useState<string | null>(null);
  const [imageError, setImageError] = useState('');
  const imageUrl = draft.imageUrl.trim();
  const sponsor = draft.placement === 'sponsor';

  function previewImage() {
    try {
      const url = new URL(imageUrl);
      if (url.protocol !== 'https:' || url.username || url.password) throw new Error();
      setImageError('');
      setImage(imageUrl);
    } catch {
      setImage(null);
      setImageError('Nhập liên kết ảnh bắt đầu bằng https://.');
    }
  }

  return (
    <form className="campaign-form" onSubmit={save} aria-labelledby="campaign-editor-title">
      <div className="campaign-form-heading">
        <h2 id="campaign-editor-title">{draft.id ? 'Sửa chiến dịch' : 'Chiến dịch mới'}</h2>
        <p className="muted">Chọn vị trí, nhập nội dung rồi kiểm tra bản xem trước.</p>
      </div>
      <div className="campaign-editor">
        <div className="campaign-fields">
          <fieldset>
            <legend>Vị trí hiển thị</legend>
            <div className="campaign-placements">
              {(['banner', 'sponsor'] as const).map((placement) => (
                <label className="campaign-placement" key={placement}>
                  <input type="radio" name="campaign-placement" value={placement} checked={draft.placement === placement}
                    onChange={() => update({ ...draft, placement })} />
                  <span><strong>{placements[placement].name}</strong><small>{placements[placement].detail}</small></span>
                </label>
              ))}
            </div>
          </fieldset>
          <fieldset>
            <legend>Nội dung quảng cáo</legend>
            <label>Tiêu đề
              <input ref={titleInput} value={draft.title} required maxLength={120} onChange={(event) => update({ ...draft, title: event.target.value })} />
            </label>
            <label>Liên kết đích (HTTPS)
              <input type="url" value={draft.targetUrl} required maxLength={2048} placeholder="https://"
                onChange={(event) => update({ ...draft, targetUrl: event.target.value })} />
            </label>
            <div className="campaign-image-field">
              <label>Liên kết ảnh (không bắt buộc)
                <input type="url" value={draft.imageUrl} maxLength={2048} placeholder="https://"
                  aria-describedby={imageError ? 'campaign-image-error' : undefined}
                  onChange={(event) => { setImageError(''); setImage(null); update({ ...draft, imageUrl: event.target.value }); }} />
              </label>
              <button type="button" className="secondary" disabled={!imageUrl} onClick={previewImage}>Xem ảnh</button>
            </div>
            {imageError && <p className="error" role="alert" id="campaign-image-error">{imageError}</p>}
          </fieldset>
          <fieldset>
            <legend>Lịch và phân phối</legend>
            <div className="campaign-schedule">
              {([['startsAt', 'Bắt đầu'], ['endsAt', 'Kết thúc']] as const).map(([key, label]) => (
                <label key={key}>{label}
                  <input type="datetime-local" required value={localDate(draft[key])}
                    onChange={(event) => {
                      if (event.target.value) update({ ...draft, [key]: new Date(event.target.value).toISOString() });
                    }} />
                </label>
              ))}
              <label>Loại liên kết
                <select value={draft.linkType} onChange={(event) => update({ ...draft, linkType: event.target.value === 'affiliate' ? 'affiliate' : 'sponsored' })}>
                  <option value="sponsored">Tài trợ</option>
                  <option value="affiliate">Tiếp thị liên kết</option>
                </select>
              </label>
              <label>Trọng số
                <input type="number" min={1} max={100} required value={draft.weight}
                  onChange={(event) => update({ ...draft, weight: Number(event.target.value) })} />
              </label>
            </div>
            <label className="checkbox">
              <input type="checkbox" checked={draft.enabled} onChange={(event) => update({ ...draft, enabled: event.target.checked })} />
              Bật chiến dịch trong lịch chạy
            </label>
          </fieldset>
        </div>
        <section className="campaign-preview" aria-labelledby="campaign-preview-title">
          <h3 id="campaign-preview-title">Xem trước</h3>
          <p className="muted">{placements[draft.placement].name}</p>
          <div className={sponsor ? 'campaign-preview-window is-sponsor' : 'campaign-preview-window'}>
            {sponsor ? (
              <div className="campaign-preview-file">
                <Icon name="play" />
                <strong>Tệp của bạn</strong>
                <span>Đang chuẩn bị MP4…</span>
              </div>
            ) : <div className="campaign-preview-file"><strong>Link của bạn. Tệp bạn cần.</strong></div>}
            <div className={sponsor ? 'prepare-sponsor' : undefined}>
              <div className="advert" onError={() => { setImage(null); setImageError('Ảnh không tải được. Kiểm tra lại liên kết ảnh.'); }}>
                <AdCreative title={draft.title.trim() || 'Tiêu đề quảng cáo'} imageUrl={image} />
              </div>
            </div>
          </div>
          <p className="muted">Bản xem trước chỉ hiển thị bố cục và nội dung, không tính lượt xem hay lượt nhấp.</p>
        </section>
      </div>
      <div className="form-actions">
        <button className="primary" disabled={busy}>Lưu chiến dịch</button>
        <button type="button" className="secondary" onClick={close}>Đóng</button>
      </div>
    </form>
  );
}
