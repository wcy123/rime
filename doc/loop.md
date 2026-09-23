Introduction
============


`(rime loop)` library mimic the common lisp loop facility with many
modifications, while the bacis idea is similar, also borrow some ideas
from Python list comprehension.

# Basic Iteration

## Arithmetic Iteration

```scheme
:for <var>
    [{:from :upfrom :downfrom} <expr1>}]
    [{:to :upto :downto :below :above} <expr2>}]
    [:by <expr3>]
```

for example

```scheme
(loop :for i :from 0 :to 2 :collect i) ; => (0 1 2)
```

## List Iteration

Iterate on each element.

```scheme
:for <var> {:in :on} <list-expr>
```

```scheme
(loop :for i :in '(1 2 3) :collect i) ; => (1 2 3)
```

Iterate on each sub-list

```scheme
(loop :for i :on '(1 2 3) :collect i) ; => ((1 2 3) (2 3) (3))
```

## Vector Iteration

```scheme
:for <var> :in-vector <vector-expr> {:offset <offset-expr>}
```

```scheme
(loop :for i :in-vector '#(1 2 3) :collect i) ; => (1 2 3)
```

`:offset` keyword is used to start from a different position other than 0.

## String Iteration


```scheme
:for <var> :in-string <string-expr> {:offset <offset-expr>}
```


```scheme
(loop :for i :in-string "HELLO" :collect i) ; => (#\H #\E #\L #\L #\O)
```

`:offset` keyword is used to start from a different position other than 0.

```scheme
(loop :for i :in-string "HELLO" :offset 2 :collect i) ; => (#\L #\L #\O)
```

## Hashtable Iteration

```scheme
:for (<var-key> <var-value>) :in-hashtable <hashtable-expr>
```

```scheme
(define ht (make-eq-hashtable))
(hashtable-set! ht 1 "one")
(hashtable-set! ht 2 "two")
(hashtable-set! ht 3 "three")
(sort (lambda (x y) (< (car x) (car y)))
      (loop :for (k v) :in-hashtable ht
            :collect (cons k v)))
;; => ((1 . "one") (2 . "two") (3 . "three"))
```

## `:if` `:when` `:unless` for fitering.

```scheme
{:if :when :unless} <cond>
```

Similiar to Python list comprehension, `:if` is used to fiter out
elements which does not match a certain condition. `:when` is an alias
of `:if`, and `:unless cond` is as same as `:if (not cond)`

```scheme
(loop :for i :from 0 :to 8
      :if (odd? i)
      :collect i) ; => (1 3 5 7)

(loop :for i :from 0 :to 8
      :unless (even? i)
      :collect i) ; => (1 3 5 7)
```

## Parallel Iteration

There are can be more than one `:for` clauses and if any of the
clauses is ended, the who loop is ended also.

```scheme
(loop :for i :from 0 :to 8
      :for c :in '(a b c)
      :collect (cons i c)) ; => ((0 . a) (1 . b) (2 . c))
```

so that above example can also be written as below.

```scheme
(loop :for i :from 0
      :for c :in '(a b c)
      :collect (cons i c)) ; => ((0 . a) (1 . b) (2 . c))
```


## Accumulate, `:collect` and `:append`

```scheme
{:collect :append} <expr> {[:if cond-expr ]|[:unless cond-expr ]|[:when cond-expr ]|[ :into <var> ]}*
```

As above examples have shown, a loop expression return a value, by default it is `(void)`.

```scheme
(loop :for i :from 0 :to 1) ;; => (void)
```

A `:collect` clause is used to for collect an expression into a list
and return the list as the return value of the whole loop expression.

`flat-map` is a common pattern in functional programming so that
`:append` keywords is used for this purpose, it quite similar to
`:collect`, except that it consumes an expression and assume the
expression is evaluated into a list and collect each elements into a
list.

```scheme
(loop :for index :from 0
      :for ch :in '(a b c)
      :append (list index ch)) ; => (0 a 1 b 2 c)
```

we can swap subclasses, for example, `:collect <expr> :into <var> :if
<cond>` is same as `:collect <expr> :into <var> :if <cond>`.

NOTE: `:collect` clause initialize the return value of the whole loop
expression with `()`, so that an empty iteration results in `()`
returned, for example,

```scheme
(loop :for index :in '()
      :collect index) ; => (), not #void
```

it implies that `:initially := '()`, see also `:initially clauses`


`:append <expr> :into <var>` and `:collect <expr> :into <var>`
accumulate elements into a new variable other than `:return-value`.

`:if` , `:when` and `:unless` is used to filter out some values, e.g.

```scheme
(loop :for i :from 0 :to 10 :collect i :if (odd? i))
;; => (1 3 5 7 9)
```

## `:count`

```
:count [:into <var>] [:step <expr>] [:by <key>] [:if <cond>] [:unless <cond>] [:when <cond>] [:make-hash-table <expr>]
```

The `:count` clause has two modes:

1. **Simple counting**: Accumulates a numeric count (default increment is 1)
2. **Grouping mode**: When `:by <key>` is used, creates a hashtable that counts occurrences of each key

**Basic counting (counts iterations):**

```scheme
(loop :for i :from 1 :to 5 :count)  ; => 5
```

**Conditional counting with `:if/:when/:unless`:**

```scheme
(loop :for ch :in-string "Hello World"
      :count :if (char-upper-case? ch))  ; => 2

(loop :for i :from 1 :to 10
      :count :when (even? i))  ; => 5

(loop :for i :from 1 :to 10
      :count :unless (< i 5))  ; => 6
```

**Custom increment with `:step`:**

By default, `:count` increments by 1. Use `:step <expr>` to increment by a different amount:

```scheme
(loop :for i :from 1 :to 5 :count :step 2)  ; => 10 (counts 5 times, adding 2 each)

(loop :for i :from 1 :to 5 :count :step i)  ; => 15 (sum: 1+2+3+4+5)
```

**Count into variable with `:into`:**

```scheme
(loop :for i :from 1 :to 10
      :count :into evens :step i :if (even? i)
      :count :into odds :step i :if (odd? i)
      :finally (cons evens odds))  ; => (30 . 25)
```

**Practical example - weighted scoring:**

```scheme
(loop :for score :in '(80 90 100 70 60)
      :for weight :in '(1 1 2 1 1)
      :count :into total :step (* score weight)
      :finally total)  ; => 500
```

**Grouping mode with `:by <key>`:**

When `:by` is used, `:count` creates a hashtable that counts occurrences of each key:

```scheme
;; Count occurrences of each number
(loop :for i :in '(1 2 1 2 3 1 2 3)
      :count :by i)
; => hashtable with {1:3, 2:3, 3:2}

;; Count with conditions
(loop :for i :in '(1 2 1 2 3 1 2 3)
      :count :by i :if (odd? i))
; => hashtable with {1:3, 3:2}

;; Custom hash function with :make-hash-table
(loop :for str :in (map string (string->list "Hello World"))
      :count :by str
      :make-hash-table (make-hashtable string-hash string=?))
; => hashtable with {"H":1, "e":1, "l":3, "o":2, " ":1, "W":1, "r":1, "d":1}
```

**Important distinctions:**
- `:step` - Controls the increment amount in simple counting mode
- `:by` - Switches to grouping mode, creates a hashtable counting by key
- `:into` - Works with both modes (stores numeric result or hashtable)

## `:do` clause

```
:do <expr> {[:if cond-expr ]|[:unless cond-expr ]|[:when cond-expr ]}
```

`:do` clause is used to evaluate an expression with side effects.

```scheme
(loop :for index :from 0
      :for ch :in '(a b c)
      :append (list index ch)
      :do (display (list index ch))) ; => (0 a 1 b 2 c)
```

The optional `:if` subclause can control whether evaluate `:do` clause or not.

## `:with` clause

```
:with <var> := <expr>
```

`:with` clause is used to create an intermediate variable not only
improve readability but als to avoid evaluate a common expression more
than twice.


```scheme
(loop :for index :from 0
      :for ch :in '(a b c)
      :with pair := (list index ch)
      :append pair
      :do (display (list index ch))) ; => (0 a 1 b 2 c)
```

`:with` clause can not only create a new variable but also change the value, and used by other clauses


```scheme
(loop :for index :from 0
      :for ch :in-string "this is HELLO."
      :with is_uppercase := (char-upper-case? ch)
      :if is_uppercase
      :with 1000_plus_pos := (+ 500 index)
      :with 1000_plus_pos := (+ 500 1000_plus_pos)
      :collect 1000_plus_pos) ; => (1008 1009 1010 1011 1012)

```

## `:initially` clause

```
:initially ([<var>] := <expr>) ...
```

`<var>` is assigned to `<expr>` before iteration started, and all
`<var>` are visiable in `:finally` clauses. There can be more than one
`:initially` clauses.

`<var>` is optional, by default it is `:return-value`.

There can be more than one variable bindings.

## `:finally` clause

```
:finally <expr>
```

`:finally` expression is evaluated after the loop is ended, and the
value of the expression is the return value of the whole loop
expression.

```scheme
(loop :for i :from 0 :to 2
      :collect i
      :finally (map (lambda (x) (+ 100 x)) :return-value)) ; => (100 101 102)
```

`:return-value` can be used to access the current return value of the
whole expression anywhere inside a loop expression.

**Note:** Only ONE `:finally` clause is supported. To chain multiple transformations, nest them:

```scheme
(loop :for i :from 0 :to 2
      :collect i
      :finally (map (lambda (y) (+ 1000 y))
                    (map (lambda (x) (+ 100 x)) :return-value))) ; => (1100 1101 1102)
```

## `:break` clause

```
:break [<expr>] [{:if :when :unless} <cond>]
```

`:break` expression is used to terminate the loop expression earlier.

```scheme
(loop :for i :from 0 :to 2
      :break
      :collect i)
;; => ()
```

`:break` can return a value as the whole loop expression. `:break`
without a return value does not change the current return value.

```scheme
(loop :for i :from 0 :to 2
      :break 100
      :collect i) ; => 100
```

`:break expr :if cond` is more common than a bear `:break`.

```scheme
(loop :for i :from 0 :to 200
      :break :if (> i 2)
      :collect i) ; => (0 1 2)
```

NOTE: `:if` is part of `:break` clause, it is not a standalone `:if` clause.

## Nested Loop, `:loop` clause

```
(:loop <all other valid loop clauses>)
```

As mentioned in above, multiple `:for` clauses mean parallele
iteration, if any of them is terminated, the whole loop is
terminated. `:loop` is used to support nested loop.

```scheme
(loop :for i :in '(0 1 2)
      (:loop :for j :in '(a b c)
             :collect (cons i j)))
;; =>
;; ((0 . a)
;;  (0 . b)
;;  (0 . c)
;;  (1 . a)
;;  (1 . b)
;;  (1 . c)
;;  (2 . a)
;;  (2 . b)
;;  (2 . c))
```

It is not as same as embeding another loop expression, for example

```scheme
(loop :for i :in '(0 1 2)
      :append (loop :for j :in '(a b c)
                       :collect (cons i j)))
;; =>
;; (((0 . a) (0 . b) (0 . c))
;;  ((1 . a) (1 . b) (1 . c))
;;  ((2 . a) (2 . b) (2 . c)))
```

To get same result, we need `:append` instead `:collect` in the outer loop expression.

```scheme
(loop :for i :in '(0 1 2)
      :append (loop :for j :in '(a b c)
                    :collect (cons i j)))
```

However, embeding another loop expression is slower, because a list
object is created for the inner loop expression. On the other hand,
`:loop` clauses share all variables created by `:initially` clause,
`with` clauses and `:return-value`.

all `:initially` clauses inside `:loop` are shared the same
enviornment bindings of the top level loop exrpession.

While `:finally` clauses of a `:loop` clauses are evaluated at the end
of its own iteration.

more examples,

```scheme
(loop :for i :in '(0 1 2)
      :collect i
      (:loop :for j :from i :to 2
             :collect (cons i j)))
;; =>
;; (0 (0 . 0) (0 . 1) (0 . 2)
;;  1 (1 . 1) (1 . 2)
;;  2 (2 . 2))
```

## `:recur` - State Variables That Persist Across Loop Rounds

The `:recur` clause creates variables that **persist and accumulate state** as the loop runs. 

**Key difference from `:for`:**
- **`:for` variables** are bound to an iteration sequence - they reset for each new sequence
- **`:recur` variables** accumulate across ALL rounds - they remember and build on previous values

This enables patterns impossible with `:for` alone:
- **Fibonacci**: track two previous values (F[n-1], F[n]) across all rounds
- **Running totals**: accumulate sums, products, or counts
- **Sliding windows**: remember the previous element
- **Recursive traversal**: combine with `:name` to restart the loop with updated state

### Syntax

```scheme
:recur <var> := <init-value> :then <next-value-expr>
```

- `<var>` - Variable name that holds the evolving state
- `<init-value>` - Initial value before the loop starts
- `<next-value-expr>` - Expression to compute the next value (can reference current loop variables)

### How It Works

Each `:recur` clause creates a variable that:
1. Starts with `<init-value>` before the loop begins
2. Gets updated to `<next-value-expr>` when moving to the next round
3. Can reference other loop variables and other `:recur` variables

Multiple `:recur` clauses can work together, and they can reference each other (they update in declaration order).

### Example 1: Fibonacci Sequence

Computing Fibonacci numbers requires tracking two previous values:

```scheme
(loop :repeat 10
      :recur x0 := 0 :then x      ; previous value: starts at 0, then becomes current x
      :recur x := 1 :then (fx+ x0 x)  ; current value: starts at 1, then becomes sum
      :collect x)
;; => (1 1 2 3 5 8 13 21 34 55)
```

**Explanation:**
- `x0` tracks the previous Fibonacci number (F[n-1])
- `x` tracks the current Fibonacci number (F[n])
- After each round: `x0` becomes the old `x`, and `x` becomes `x0 + x`
- We collect `x` to build the sequence

**Execution trace:**
```
Round 1:  x0=0,  x=1    → collect 1, then update: x0←1, x←1
Round 2:  x0=1,  x=1    → collect 1, then update: x0←1, x←2
Round 3:  x0=1,  x=2    → collect 2, then update: x0←2, x←3
Round 4:  x0=2,  x=3    → collect 3, then update: x0←3, x←5
Round 5:  x0=3,  x=5    → collect 5, then update: x0←5, x←8
...
```

### Example 2: Factorial

Computing factorial requires accumulating a product:

```scheme
(loop :for i :from 1 :to 5
      :recur result := 1 :then (fx* result i)
      :finally result)
;; => 120
```

**Explanation:**
- `result` accumulates the product: 1 × 1 × 2 × 3 × 4 × 5 = 120
- Initial value is 1 (multiplicative identity)
- Each round multiplies `result` by the current `i`

### Example 3: Running Sum

Creating a list of cumulative sums:

```scheme
(loop :for i :from 1 :to 5
      :recur sum := 0 :then (fx+ sum i)
      :collect sum)
;; => (0 1 3 6 10)
```

**Explanation:**
- We collect the sum **before** it's updated
- Round 1: sum=0, collect 0, then update to 0+1=1
- Round 2: sum=1, collect 1, then update to 1+2=3
- Round 3: sum=3, collect 3, then update to 3+3=6
- etc.

### Example 4: Powers of 2

Generating exponential sequences:

```scheme
(loop :repeat 8
      :recur power := 1 :then (fx* power 2)
      :collect power)
;; => (1 2 4 8 16 32 64 128)
```

**Explanation:**
- Start with `power=1`
- Each round doubles: 1 → 2 → 4 → 8 → 16 → ...

### Example 5: Sliding Window (Tracking Previous Value)

Pairing each element with its predecessor:

```scheme
(loop :for i :in '(10 20 30 40 50)
      :recur prev := #f :then i
      :collect (cons prev i))
;; => ((#f . 10) (10 . 20) (20 . 30) (30 . 40) (40 . 50))
```

**Explanation:**
- `prev` starts as `#f` (no previous element yet)
- Each round: `prev` becomes the previous round's `i`
- Creates pairs showing the transition from one element to the next

### When to Use `:recur`

Use `:recur` when you need to:
- **Compute recurrence relations** (Fibonacci, factorial, etc.)
- **Track state across loop rounds** (running totals, sliding windows)
- **Generate sequences** where each value depends on previous values
- **Accumulate results** incrementally (when `:count`/`:collect` alone isn't enough)

### Comparison with Other Features

| Feature | Use Case | Example |
|---------|----------|---------|
| `:recur` | State that evolves based on previous values | Fibonacci, running sum |
| `:count :into` | Simple accumulation with custom increment | Weighted counting |
| `:with :=` | Loop-invariant values (computed once) | Constants, pre-computed values |
| `:initially` | One-time setup code before loop starts | Initialize external state |

### How It Works

`:recur` creates bindings in the **outer named `let`**, while `:for` creates bindings in the **inner named `let`**.

**Quick example:**

```scheme
(loop :for i :from 1 :to 3
      :recur sum := 0 :then (fx+ sum i)
      :collect (cons sum i))
;; => ((0 . 1) (1 . 2) (3 . 3))
```

- Round 1: `sum=0`, `i=1` → collect `(0 . 1)` → update to `sum=1`
- Round 2: `sum=1`, `i=2` → collect `(1 . 2)` → update to `sum=3`
- Round 3: `sum=3`, `i=3` → collect `(3 . 3)` → update to `sum=6`

Notice: we collect the value **before** the `:then` expression updates it.

For the detailed expansion showing the nested `let` forms, see [rime-internal.md](rime-internal.md#concrete-example-3-recur-clause).
## named loop

A loop expression can be named with `:named` keyword, similiar to
named `let` expression. The `(loop :name recur :for i :in '(1 2 3)
...` loop structure is translate into a named `let` similiar to below.

```scheme
(let recur ([i '(1 2 3)])
   (when (null? i)
       ....
      (recur (cdr i))))
```

so that we can implement `deep-flatten` as below,

```scheme
(loop :name recur
      :for i :in '(0 1 2 (1 11 (20 21 22) 12) 3 4 5)
      :do (recur i) :if (list? i)
      :collect i :unless (list? i)
)
;; => (0 1 2 1 11 20 21 22 12 3 4 5)
```

# Some Practical Examples

## `map`

```scheme
(define map
  (lambda (f lst)
     (loop :for i :in lst :collect (f i))))

(map odd? '(1 2 3)) => (#t #f #f)
```

## `filter`

```scheme
(define filter
  (lambda (f lst)
     (loop :for i :in lst :if (f i) :collect i)))

(filter odd? '(1 2 3)) => (1 3)
```

## `string-starts`

```scheme
(define string-start
    (lambda (prefix from str)
       (loop :for c1 :in-string prefix
             :for c2 :in-string str :offset from
             :break :unless (char=? c1 c2)
             :count
             :finally (fx=? (string-length prefix) :return-value))))

(string-start "loop-" 5 "this-loop-parser") ; => #t
(string-start "loop-" 0 "this-loop-parser") ; => #f
(string-start "loop-" 0 "x") ; => #f
```

## `intersection`

```scheme
(define intersection
    (lambda (list-a list-b)
       (loop :for c1 :in list-a
             (:loop :for c2 :in list-b
                    :if (eq? c1 c2)
                    :collect c2))))
(intersection '(a b c) '(b c d)) ;; => b c
```


## `get-column-line-number`

```scheme
(define (get-column-line-number file-name position)
  (call-with-port (open-file-input-port file-name
                                        (file-options)
                                        (buffer-mode block)
                                        (native-transcoder))
    (lambda (port)
      (loop :initially line-number := 1
            :initially column-number := 1
            :for pos :upfrom 0
            :with ch := (get-char port)
            :break #f :if (eof-object? ch)
            :count :into column-number
            :break :unless (fx<? pos position)
            :if (char=? ch #\newline)
            :count :into line-number
            :with column-number := 0
            :finally (cons line-number column-number)
            ))))
```

Given a file name `file-name` and character position `position`,
`get-column-line-number` returns a pair which contains line number and
column.

## member? - Check if element exists

```scheme
(define (member? x lst)
  (loop :for item :in lst
        :if (equal? x item)
        :break #t))

(member? 'b '(a b c))  ; => #t
(member? 'd '(a b c))  ; => #<void>
```

**Note:** Don't use `:finally #f` with `:break` - see PITFALLS section below.

## list-index - Find index of element

```scheme
(define (list-index x lst)
  (loop :for item :in lst
        :for index :from 0
        :if (equal? x item)
        :break index))

(list-index 'b '(a b c))    ; => 1
(list-index 'd '(a b c))    ; => #<void>
```

## vector-index - Find index in vector

```scheme
(define (vector-index x vec)
  (loop :for item :in-vector vec
        :for index :from 0
        :if (equal? x item)
        :break index))

(vector-index 20 (vector 10 20 30))  ; => 1
(vector-index 40 (vector 10 20 30))  ; => #<void>
```

## find-first - Find first element satisfying predicate

```scheme
(define (find-first pred lst)
  (loop :for item :in lst
        :if (pred item)
        :break item))

(find-first even? '(1 3 4 5 6))  ; => 4
(find-first even? '(1 3 5))      ; => #<void>
```

## count-occurrences - Count element occurrences

```scheme
(define (count-occurrences x lst)
  (loop :for item :in lst
        :if (equal? x item)
        :count))

(count-occurrences 'a '(a b a c a))  ; => 3
(count-occurrences 'd '(a b c))      ; => 0
```

# More Practical Examples

## Simple list building - Use `:collect`

For simple list building, use `:collect` - it's clearer and more efficient:

### list-indices - Find all indices of element

```scheme
(define (list-indices x lst)
  (loop :for item :in lst
        :for index :from 0
        :when (equal? x item)
        :collect index))

(list-indices 'a '(a b a c a))  ; => (0 2 4)
(list-indices 'd '(a b c))      ; => ()
```

### my-filter - Filter using `:collect`

```scheme
(define (my-filter pred lst)
  (loop :for item :in lst
        :when (pred item)
        :collect item))

(my-filter even? '(1 2 3 4 5 6))  ; => (2 4 6)
```

### my-map - Map using `:collect`

```scheme
(define (my-map f lst)
  (loop :for item :in lst
        :collect (f item)))

(my-map (lambda (x) (* x 2)) '(1 2 3))  ; => (2 4 6)
```

### zip - Zip two lists

```scheme
(define (zip lst1 lst2)
  (loop :for a :in lst1
        :for b :in lst2
        :collect (cons a b)))

(zip '(a b c) '(1 2 3))  ; => ((a . 1) (b . 2) (c . 3))
```

### range - Generate range

```scheme
(define (range start end)
  (loop :for i :from start :to end
        :collect i))

(range 0 5)  ; => (0 1 2 3 4 5)
```

### take - Take first n elements

```scheme
(define (take n lst)
  (loop :for item :in lst
        :for count :from 1 :to n
        :collect item))

(take 3 '(a b c d e))  ; => (a b c)
```

## When to use manual accumulation: `cons + set! + reverse`

Use manual accumulation ONLY when you need side effects along with collection:

### remove-duplicates - Side effects require manual pattern

```scheme
(define (remove-duplicates lst)
  (loop :initially seen := (make-eq-hashtable)
        :initially acc := '()
        :for item :in lst
        :unless (hashtable-contains? seen item)
        :do (hashtable-set! seen item #t)     ; Side effect: update hashtable
        :do (set! acc (cons item acc))        ; Manual accumulation
        :finally (reverse acc)))

(remove-duplicates '(a b a c b d))  ; => (a b c d)
```

**Why manual here?** We need to update the `seen` hashtable AND collect items. 
`:collect` alone can't express "do side effect, then collect conditionally."

## Universal Scheme Pattern: cons + accumulator + reverse

The manual accumulation pattern (`cons` + `set!` + `reverse`) is a universal Scheme idiom
that works everywhere: recursive functions, loop macros, DAG traversal.

**Comparison:**

```scheme
;; Loop macro with :collect
(loop :for item :in lst
      :when (pred item)
      :collect item)

;; Recursive function (same mental model)
(define (recursive-filter pred lst)
  (let loop ((remaining lst) (acc '()))
    (if (null? remaining)
        (reverse acc)
        (loop (cdr remaining)
              (if (pred (car remaining))
                  (cons (car remaining) acc)
                  acc)))))
```

**When to use each:**
- **Use `:collect`** - Simple list building without side effects (99% of cases)
- **Use manual accumulation** - When you need side effects + collection together

## PITFALLS

### Pitfall 1: `:finally` ALWAYS overrides return value

`:finally` executes even after `:break`, and REPLACES the return value!

**WRONG:**
```scheme
(define (member? x lst)
  (loop :for item :in lst
        :if (equal? x item)
        :break #t
        :finally #f))  ; This ALWAYS returns #f!

(member? 'b '(a b c))  ; => #f (NOT #t!)
```

**Why?** `:finally #f` runs after `:break #t` and overrides it.

**RIGHT:** Don't use `:finally` with `:break`:
```scheme
(define (member? x lst)
  (loop :for item :in lst
        :if (equal? x item)
        :break #t))

(member? 'b '(a b c))  ; => #t
(member? 'd '(a b c))  ; => #<void> (not #f!)
```

### Pitfall 2: `:with` doesn't work for reassignment

`:with` creates improper lists when trying to reassign:

**WRONG:**
```scheme
(loop :initially acc := '()
      :for i :from 1 :to 3
      :with acc := (cons i acc)
      :finally acc)
; => (3 2 1 . #<void>)  -- IMPROPER LIST!
```

**RIGHT:** Use `:do` with `set!`:
```scheme
(loop :initially acc := '()
      :for i :from 1 :to 3
      :do (set! acc (cons i acc))
      :finally acc)
; => (3 2 1)  -- proper list
```

### Pitfall 3: Loop without `:finally` returns `#<void>`

If loop completes without `:break` or `:finally`, returns `#<void>`:

```scheme
(loop :for i :from 1 :to 3
      :do (display i))
; => #<void>
```

Use `:finally` to control the return value, or use `:collect`/`:count`.

## Why This Pattern?

**Universal:** Same mental model as recursive functions:

```scheme
(define (recursive-filter pred lst)
  (let loop ((remaining lst) (acc '()))
    (if (null? remaining)
        (reverse acc)
        (loop (cdr remaining)
              (if (pred (car remaining))
                  (cons (car remaining) acc)
                  acc)))))
```

**Efficient:** `cons` is O(1), `reverse` is O(n) once.

**Standard:** Every Scheme programmer recognizes this idiom.
