# Light Theme Implementation Tasks

## Current Issues

- App background remains dark in light mode
- Text colors are white instead of black in light mode
- Widgets use hardcoded dark colors and gradients

## Tasks

- [ ] Modify AppTheme to have dynamic text style methods using Theme.of(context)
- [ ] Update color constants to be theme-aware
- [ ] Update key widgets to use dynamic styles instead of static ones
- [ ] Test light theme implementation
- [ ] Ensure all backgrounds are white and texts are black in light mode

## Files to Update

- lib/utils/theme.dart - Add dynamic text style methods
- Key widgets using AppTheme static styles
- Test theme switching in settings
