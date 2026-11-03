/** Fixed Redis windows; rejected attempts also consume their applicable bucket. */
export const ratePolicy = {
  feedbackSession: { max: 3, seconds: 600 },
  feedbackIp: { max: 10, seconds: 3600 },
  sessionCreate: { max: 10, seconds: 60 },
  analyzeSession: { max: 10, seconds: 60 },
  analyzeIp: { max: 30, seconds: 60 },
  loginIp: { max: 5, seconds: 300 },
  ticketSession: { max: 10, seconds: 60 },
  ticketJob: { max: 5, seconds: 60 },
} as const;
