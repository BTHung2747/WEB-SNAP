export type Session = {
  productName: string;
  csrf: string;
  supported: string[];
  contact: string | null;
  heartbeatSeconds: number;
  capabilities?: { tiktokPhoto?: boolean };
};
export type Format = {
  id: string;
  label: string;
  size: number | null;
  kind?: 'photo';
  imageCount?: number;
  index?: number;
  width?: number;
  height?: number;
  sourceDefault?: boolean;
  highest?: boolean;
  previewUrl?: string | null;
};
export type Job = {
  id: string;
  state: string;
  errorCode: string | null;
  title: string | null;
  duration: number | null;
  items: {
    id: string;
    kind: string;
    formats: Format[];
  }[];
  previewUrl: string | null;
};
export type Ad = {
  id: string;
  title: string;
  imageUrl: string | null;
  targetUrl: string;
  placement: string;
  linkType: string;
};
