SELECT 'DownloadJob' AS entity, count(*) AS rows FROM "DownloadJob"
UNION ALL SELECT 'AdCampaign', count(*) FROM "AdCampaign"
UNION ALL SELECT 'Settings', count(*) FROM "Settings"
UNION ALL SELECT 'Migration', count(*) FROM "_prisma_migrations";
