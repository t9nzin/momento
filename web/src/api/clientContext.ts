import { COMPONENT_TYPES, SCHEMA_VERSION, type ComponentType } from '../schema/types';

export type VariantChoice = 'auto' | 'A' | 'B';

/** How this client describes itself to the server on every screen request. */
export interface ClientContext {
  userId: string;
  /** `auto` lets the server bucket the user; A or B forces a layout for demos. */
  variant: VariantChoice;
  supportedComponents: readonly ComponentType[];
}

export const DEFAULT_CLIENT_CONTEXT: ClientContext = {
  userId: 'web-demo-user',
  variant: 'auto',
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
