# Fixture — two levels of nested fence must not close the block early

A depth counter must close each inner fence in turn — mistaking either
inner close for the outer block's own close would drop everything after it
from being checked at all.

```output
Fine so far.
```js
const x = 1;
```python
nested_deeper = True
```
back in the js sample
```
We utilize this leverage kindly, certainly, going forward.
```
