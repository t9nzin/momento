import { Button } from './components/Button';
import { Card } from './components/Card';
import { Column, Row } from './components/Stack';
import { Grid } from './components/Grid';
import { Image } from './components/Image';
import { List } from './components/List';
import { Spacer } from './components/Spacer';
import { Text } from './components/Text';
import type { ComponentRegistry } from './types';

/**
 * Maps every schema type to the React component that draws it. The mapped
 * type makes a missing entry a compile error, so adding a type to the schema
 * forces a renderer for it.
 */
export const registry: ComponentRegistry = {
  column: Column,
  row: Row,
  text: Text,
  image: Image,
  card: Card,
  grid: Grid,
  list: List,
  button: Button,
  spacer: Spacer,
};
