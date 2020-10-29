# Sansa

This is a fork from a previous project.
*The goal*: Build a trading bot based on identified daily zones and pass orders on lower timeframes (H1 mainly).

__What's done:__
* puller des zones pour le moment remplies à la main
* connecteur oanda (repris de l'ancien projet)

__TODO:__
* ajouter un price watcher qui pull à intervalles réguliers
* implémenter les pattern de prise de position
* implémenter le module de prise de décision
* ajouter un reporting sur slack

---

### Zones format :
```
{
    h: [borne haute],
    l: [borne basse],
    bias: [buy ou sell - facultatif]
}
```