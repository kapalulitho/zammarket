import {createContext,useContext} from 'react';
export const WorkspaceContext=createContext(null);
export function useWorkspacePlans(){return useContext(WorkspaceContext);}
