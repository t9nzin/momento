import { createContext, useContext } from 'react';
import type { Action } from '../schema/types';

export type ActionDispatcher = (action: Action) => void;

const ActionContext = createContext<ActionDispatcher>((action) => {
  console.warn('[sdui] action dispatched with no ActionContext provider', action);
});

export const ActionProvider = ActionContext.Provider;

export function useActionDispatcher(): ActionDispatcher {
  return useContext(ActionContext);
}
