import { COMPONENT_TYPES, SCHEMA_VERSION, type ComponentType } from '../schema/types';

/** How this client describes itself to the server on every screen request. */
export interface ClientContext {
  userId: string;
  supportedComponents: readonly ComponentType[];
}

export const DEFAULT_CLIENT_CONTEXT: ClientContext = {
  userId: 'web-demo-user',
  supportedComponents: COMPONENT_TYPES,
};

export function contextHeaders(context: ClientContext): Record<string, string> {
  return {
    'X-User-Id': context.userId,
    'X-Platform': 'web',
    'X-Schema-Version': String(SCHEMA_VERSION),
    'X-Supported-Components': context.supportedComponents.join(','),
  };
}
