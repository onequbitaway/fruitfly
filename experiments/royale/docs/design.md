# Fruitfly Royale

Ten flies start around one dish. Food is bait. The ring closes. One fly wins.

Palette: blue paper #E5EEF2, dish #C9DCE3, ink #193746, ring #2B7184,
blood #B82440, food #EAA34B. Red marks damage. Food stays amber.
Use Avenir Next Condensed Heavy for the title and Avenir Next for text.

Layout: the round arena fills the left two thirds. A tall roster on the
right shows ten distinct names, health, and each fly's measured activity.
Controls sit under the title. A thin event strip sits below the dish.

```
Fruitfly Royale                          Round / time
Start / pause   New round   Brain mode   Blood
                 _____                   10 flies
              /         \                roster
             |   arena   |               health
              \         /                activity
                 -----                   winner
Double-click to drop food.               selected brain
Recent knockouts                         model speed
```

Review: a dark red fighting-game dashboard would be a generic treatment.
Use a bright specimen dish instead. Make the ten moving flies the focus.
The roster carries identity without adding labels around every small object.
The ring and blood use motion to show actual game events.

Brain cells and connections come from the existing model. Each fly owns
its own state and seed. Movement, contact attacks, health, healing, blood,
and the closing ring are game rules. They are not learned fly behavior.
Draw brain activity from calculated values only. Show slower model time
when a calculation cannot keep pace. Do not replace missing frames with
invented spikes.
