# Sansa

This is a fork from a previous project.
*The goal*: Build a trading bot based on identified daily zones and pass orders on lower timeframes (H1 mainly).

__What's done:__
* puller des zones pour le moment remplies à la main
* connecteur oanda (repris de l'ancien projet)
* ajouter un price watcher qui pull à intervalles réguliers
* implémenter les pattern de prise de position
* ajouter un reporting sur slack

__TODO:__

* implémenter le module de prise de position
* conception du pattern double top?
* more tests


---

### Zones format :
```
{
    h: [borne haute],
    l: [borne basse],
    bias: [buy ou sell - facultatif]
}
```

### Price format
```
{
    open: ...
    close: ...
    high: ...
    low: ...
    spread: ...
    time: ... (unix ts)
}