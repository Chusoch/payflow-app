import app from './app';
import { config } from './config';

const PORT = config.port;
const HOST = config.host;

app.listen(PORT, HOST, () => {
  console.log(`====================================================`);
  console.log(`🚀 PayFlow Backend Server running on http://${HOST}:${PORT}`);
  console.log(`🌍 Environment: ${config.nodeEnv}`);
  console.log(`🔥 Firebase Project ID: ${config.firebaseProjectId}`);
  console.log(`🛠️ Dev Endpoints Enabled: ${config.allowDevEndpoints}`);
  console.log(`====================================================`);
});
