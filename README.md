# LiveSplit.PkmnFRLG

A [LiveSplit](https://livesplit.org/) Auto Splitter Script for Pokémon FireRed/LeafGreen on the [mGBA](https://mgba.io/) emulator.

## Supported Roms

Currently only the USA Rev. 1 versions of the games are supported:

- [**pokefirered_rev1.gba**](https://datomatic.no-intro.org/?page=show_record&s=23&n=1672) `sha1: dd5945db9b930750cb39d00c84da8571feebf417`
- [**pokeleafgreen_rev1.gba**](https://datomatic.no-intro.org/index.php?page=show_record&s=23&n=1668) `sha1: 7862c67bdecbe21d1d69ce082ce34327e1c6ed5e`

## Features

- Automatic splitting based on certain game events (does not have events for "Elite 4 Round 2" category at the moment)
- Starts the timer if a new game is started
- Resets the timer if the cursor on the main menu is on "New Game".

## Installation

1. Add the "Scriptable Auto Splitter" component to your layout (Menu -> Edit Layout).
2. Select the path to the ASL file in the settings of the component.
3. In the advanced section, you can configure the splits you want to use.
