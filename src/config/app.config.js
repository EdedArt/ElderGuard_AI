import { version } from '../../package.json';

export const appConfig = {
  name: import.meta.env.VITE_APP_NAME ?? 'ElderGuard AI',
  version,
};
