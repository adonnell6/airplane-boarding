; Andrew Donnell
; Final Project

globals [
  skin-colors            ; list of skin colors for the turtles
  open-seats             ; list of seats that are still open
  free-seat              ; color corresponding to a free seat
  taken-seat             ; color corresponding to an occupied seat
  initial-happiness      ; initial happiness, which depends on plane-type
  boarding-wait-time     ; how long to wait before moving to the next boarding group
  current-boarding-group ; current boarding group
  max-boarding-group     ; maximum possible boarding group
]

turtles-own [
  desired-seat           ; the seat I've been assigned
  desired-row            ; the patch in front of my seat
  happiness              ; my current happiness
  bag?                   ; do I have a carry-on bag?
  seated-count           ; how long I've been in my assigned seat
  delay-time             ; how long to wait before moving from aisle to seat
  my-row                 ; the row of my seat
  boarding-group         ; my assigned boarding group
  time-out-of-seat       ; time between airport seat and plane seat
]

patches-own [
  ptype                  ; type of patch, used for turtle navigation
  section                ; left-right section of the plane of the seat
  zone                   ; one of the five back-to-front zones of sears
  correct-aisle          ; notifies turtles which aisle is closest to the seat
  seat-type              ; window, middle, or aisle
]

to setup
  clear-all
  setup-globals
  color-patches
  create-passengers
  assign-boarding-groups
  reset-ticks
end

to go
  if (count patches with [pcolor = taken-seat] = count turtles) [
    stop
  ]

  ifelse label-boarding-groups?
  [ask turtles [set label boarding-group] ]
  [ask turtles [set label ""]]

  update-boarding-group

  ask turtles with [boarding-group <= current-boarding-group] [
    board-plane
    move-to-seat
  ]

  ask turtles [
    update-time-out-of-seat
  ]

  update-happinesses

  recolor-seats

  tick
end

to update-time-out-of-seat ; turtle prodecure
  if [ptype] of patch-here != "s" and [ptype] of patch-here != "as" [
    set time-out-of-seat time-out-of-seat + 1
  ]
end

to update-boarding-group ; checks conditions and updates the global boarding group
  if current-boarding-group < 0 [
    set current-boarding-group 1
  ]
  ; move to the next group if there aren't too many people in line
  if count turtles with [boarding-group <= current-boarding-group and
    ([ptype] of ([patch-here] of self) = "af" or [ptype] of
      ([patch-here] of self) = "as" or [ptype] of ([patch-here] of self) = "b")] < boarding-wait-time [
    ; cap boarding group with the max, no reason to increment past that
    set current-boarding-group min list (current-boarding-group + 1) max-boarding-group
  ]
end

to board-plane ; turtle procedure
  (ifelse
    ; if you're in an airport seat, move towards the nearest airplane floor if it isn't occupied
    [ptype] of patch-here = "as" [
      let here [patch-here] of self
      let target min-one-of (patches with [ptype = "af"]) [distance here]
      let next min-one-of (patch-set patch-here neighbors4) with [count turtles-here = 0 and ptype = "af"] [distance target]
      if next != nobody [
        move-to next
      ]
    ]
    ; if you're in an airport floor, move towards the nearest bridge patch if it isn't occupied
    [ptype] of patch-here = "af" [
      let here [patch-here] of self
      let target min-one-of (patches with [ptype = "b"]) [distance here]
      let next min-one-of (patch-set patch-here neighbors4) with [count turtles-here = 0 and ptype != "as" and ptype != "w"] [distance target]
      if next != nobody [
        move-to next
      ]
  ])
end

to move-to-seat
  ;  only if they're not in their desired seat
  if (patch-here != desired-seat and delay-time = 0) [
    let ds desired-seat

    ; if you're in your desired-row spot, get into the seat
    if patch-here = desired-row [
      let target [desired-seat] of self
      if target != nobody [
        move-to target
      ]
    ]

    ; if right before your row (equal with the seat in front of you)
    if [ptype] of patch-here = "a" and [pxcor] of patch-here = [pxcor] of desired-row + 1 [
      if bag? [ ; randomized delay for putting bag into bin
        set delay-time delay-time + 3 + random 4
      ]
      let people-to-wait-for 0 ; default to zero for the window seat
      (ifelse ; if you have to wait for people to move into the aisle to let you in, then you wait longer
        [seat-type] of desired-seat = "middle" [set people-to-wait-for people-to-wait-for + sum [count turtles-here] of (my-row with [seat-type = "aisle"])]
        [seat-type] of desired-seat = "window" [set people-to-wait-for people-to-wait-for + sum [count turtles-here] of my-row with [seat-type = "aisle" or seat-type = "middle"]])
      set delay-time delay-time + (people-to-wait-for * 5)
    ]

    ; if in the bridge, move to the aisle
    if [ptype] of patch-here = "b" or [ptype] of patch-here = "pf" or ([ptype] of patch-here = "a" and [pxcor] of patch-here >= 13 and [pycor] of patch-here != [correct-aisle] of ds)[
      let target one-of patches with [pxcor = 14 and ptype = "a" and pycor = [correct-aisle] of ds]
      let next min-one-of (patch-set patch-here neighbors4) with [count turtles-here = 0 and (ptype = "a" or ptype = "pf" or ptype = "b")] [distance target]
      if next != nobody [
        move-to next
      ]
    ]

    ; if near your row, move towards your seat
    if [ptype] of patch-here != "af" and [pxcor] of patch-here = [pxcor] of desired-row [
      if delay-time = 0 [
        let target [desired-row] of self
        let next min-one-of (patch-set patch-here neighbors4) with [count turtles-here = 0 and ptype != "s"] [distance target]
        if next != nobody and next != patch-here [
          move-to next
        ]
      ]
    ]

    ; if in the aisle, move towards your row
    if [ptype] of patch-here = "a" [
      ;; want to move towards the "a" patch closest to the row of seat
      ;;let target min-one-of patches with [ptype = "a" or ptype = "r"] [ distance [desired-row] of one-of turtles-here ]
      let target min-one-of patches with [ptype = "a"] [distance ds]
      let next min-one-of (patch-set patch-here neighbors4) with [count turtles-here = 0 and ptype = "a" and ptype != "s"] [distance target]
      if next != nobody and next != patch-here [
        move-to next
      ]
    ]
  ]

  ; decrement the delay time if it exists
  set delay-time max (list (delay-time - 1) 0)
end

to assign-boarding-groups ; turtle procedure to call helper functions
  (ifelse
    boarding-strategy = "random" [assign-random]
    boarding-strategy = "WilMA" [assign-WilMA]
    boarding-strategy = "back-to-front-5-zones" [assign-back-to-front-5-zones]
    boarding-strategy = "half-block-back-to-front" [assign-half-block-back-to-front]
    boarding-strategy = "half-block-mix-1" [assign-half-block-mix-1]
    boarding-strategy = "half-block-mix-2" [assign-half-block-mix-2]
    boarding-strategy = "by-row-back-to-front" [assign-by-row-back-to-front]
    boarding-strategy = "by-half-row-back-to-front" [assign-by-half-row-back-to-front]
    boarding-strategy = "back-to-front-by-seating-order" [assign-back-to-front-by-seating-order])
end

to assign-random ; turtle procedure
  set max-boarding-group 1
  ask turtles [set boarding-group 1]
end

to assign-WilMA ; turtle procedure
  set max-boarding-group 3
  ask turtles [
    (ifelse
      [seat-type] of desired-seat = "window" [set boarding-group 1]
      [seat-type] of desired-seat = "middle" [set boarding-group 2]
      [seat-type] of desired-seat = "aisle" [set boarding-group 3])]
end

to assign-back-to-front-5-zones ; turtle procedure
  set max-boarding-group 5
  ask turtles [set boarding-group [zone] of desired-seat]
end

to assign-half-block-back-to-front ; turtle procedure
  ifelse plane-type = "single-aisle"
  [set max-boarding-group 10]
  [set max-boarding-group 15]
  ask turtles [set boarding-group ([zone] of desired-seat) + 5 * ([section] of desired-seat - 1)]
end

to assign-half-block-mix-1 ; turtle procedure
  ask turtles [
    (ifelse
      plane-type = "single-aisle" [
        set max-boarding-group 10
        (ifelse
          [zone] of desired-seat = 1 and [section] of desired-seat = 1 [set boarding-group 1]
          [zone] of desired-seat = 1 and [section] of desired-seat = 2 [set boarding-group 6]
          [zone] of desired-seat = 2 and [section] of desired-seat = 1 [set boarding-group 7]
          [zone] of desired-seat = 2 and [section] of desired-seat = 2 [set boarding-group 2]
          [zone] of desired-seat = 3 and [section] of desired-seat = 1 [set boarding-group 3]
          [zone] of desired-seat = 3 and [section] of desired-seat = 2 [set boarding-group 8]
          [zone] of desired-seat = 4 and [section] of desired-seat = 1 [set boarding-group 9]
          [zone] of desired-seat = 4 and [section] of desired-seat = 2 [set boarding-group 4]
          [zone] of desired-seat = 5 and [section] of desired-seat = 1 [set boarding-group 5]
          [zone] of desired-seat = 5 and [section] of desired-seat = 2 [set boarding-group 10])]
      plane-type = "double-aisle" [
        set max-boarding-group 15
        (ifelse
          [zone] of desired-seat = 1 and [section] of desired-seat = 1 [set boarding-group 1]
          [zone] of desired-seat = 1 and [section] of desired-seat = 2 [set boarding-group 9]
          [zone] of desired-seat = 1 and [section] of desired-seat = 3 [set boarding-group 2]
          [zone] of desired-seat = 2 and [section] of desired-seat = 1 [set boarding-group 10]
          [zone] of desired-seat = 2 and [section] of desired-seat = 2 [set boarding-group 3]
          [zone] of desired-seat = 2 and [section] of desired-seat = 3 [set boarding-group 11]
          [zone] of desired-seat = 3 and [section] of desired-seat = 1 [set boarding-group 4]
          [zone] of desired-seat = 3 and [section] of desired-seat = 2 [set boarding-group 12]
          [zone] of desired-seat = 3 and [section] of desired-seat = 3 [set boarding-group 5]
          [zone] of desired-seat = 4 and [section] of desired-seat = 1 [set boarding-group 13]
          [zone] of desired-seat = 4 and [section] of desired-seat = 2 [set boarding-group 6]
          [zone] of desired-seat = 4 and [section] of desired-seat = 3 [set boarding-group 14]
          [zone] of desired-seat = 5 and [section] of desired-seat = 1 [set boarding-group 7]
          [zone] of desired-seat = 5 and [section] of desired-seat = 2 [set boarding-group 15]
          [zone] of desired-seat = 5 and [section] of desired-seat = 3 [set boarding-group 8])])]
end

to assign-half-block-mix-2 ; turtle procedure
  ask turtles [
    (ifelse
      plane-type = "single-aisle" [
        set max-boarding-group 10
        (ifelse
          [zone] of desired-seat = 1 and [section] of desired-seat = 1 [set boarding-group 1]
          [zone] of desired-seat = 1 and [section] of desired-seat = 2 [set boarding-group 6]
          [zone] of desired-seat = 2 and [section] of desired-seat = 1 [set boarding-group 4]
          [zone] of desired-seat = 2 and [section] of desired-seat = 2 [set boarding-group 9]
          [zone] of desired-seat = 3 and [section] of desired-seat = 1 [set boarding-group 2]
          [zone] of desired-seat = 3 and [section] of desired-seat = 2 [set boarding-group 7]
          [zone] of desired-seat = 4 and [section] of desired-seat = 1 [set boarding-group 5]
          [zone] of desired-seat = 4 and [section] of desired-seat = 2 [set boarding-group 10]
          [zone] of desired-seat = 5 and [section] of desired-seat = 1 [set boarding-group 3]
          [zone] of desired-seat = 5 and [section] of desired-seat = 2 [set boarding-group 8])]
      plane-type = "double-aisle" [
        set max-boarding-group 15
        (ifelse
          [zone] of desired-seat = 1 and [section] of desired-seat = 1 [set boarding-group 1]
          [zone] of desired-seat = 1 and [section] of desired-seat = 2 [set boarding-group 11]
          [zone] of desired-seat = 1 and [section] of desired-seat = 3 [set boarding-group 6]
          [zone] of desired-seat = 2 and [section] of desired-seat = 1 [set boarding-group 4]
          [zone] of desired-seat = 2 and [section] of desired-seat = 2 [set boarding-group 14]
          [zone] of desired-seat = 2 and [section] of desired-seat = 3 [set boarding-group 9]
          [zone] of desired-seat = 3 and [section] of desired-seat = 1 [set boarding-group 2]
          [zone] of desired-seat = 3 and [section] of desired-seat = 2 [set boarding-group 12]
          [zone] of desired-seat = 3 and [section] of desired-seat = 3 [set boarding-group 7]
          [zone] of desired-seat = 4 and [section] of desired-seat = 1 [set boarding-group 5]
          [zone] of desired-seat = 4 and [section] of desired-seat = 2 [set boarding-group 15]
          [zone] of desired-seat = 4 and [section] of desired-seat = 3 [set boarding-group 10]
          [zone] of desired-seat = 5 and [section] of desired-seat = 1 [set boarding-group 3]
          [zone] of desired-seat = 5 and [section] of desired-seat = 2 [set boarding-group 13]
          [zone] of desired-seat = 5 and [section] of desired-seat = 3 [set boarding-group 8])])]
end

to assign-by-row-back-to-front ; turtle procedure
  ask turtles [
    set max-boarding-group 14
    (ifelse
      [pxcor] of desired-seat = 11 [set boarding-group 14]
      [pxcor] of desired-seat = 9 [set boarding-group 13]
      [pxcor] of desired-seat = 7 [set boarding-group 12]
      [pxcor] of desired-seat = 5 [set boarding-group 11]
      [pxcor] of desired-seat = 3 [set boarding-group 10]
      [pxcor] of desired-seat = 1 [set boarding-group 9]
      [pxcor] of desired-seat = -1 [set boarding-group 8]
      [pxcor] of desired-seat = -3 [set boarding-group 7]
      [pxcor] of desired-seat = -5 [set boarding-group 6]
      [pxcor] of desired-seat = -7 [set boarding-group 5]
      [pxcor] of desired-seat = -9 [set boarding-group 4]
      [pxcor] of desired-seat = -11 [set boarding-group 3]
      [pxcor] of desired-seat = -13 [set boarding-group 2]
      [pxcor] of desired-seat = -15 [set boarding-group 1])]
end

to assign-by-half-row-back-to-front ; turtle procedure
  ask turtles [
    (ifelse
      plane-type = "single-aisle" [
        set max-boarding-group 28
        (ifelse
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -15 [set boarding-group 1]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -13 [set boarding-group 2]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -11 [set boarding-group 3]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -9 [set boarding-group 4]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -7 [set boarding-group 5]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -5 [set boarding-group 6]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -3 [set boarding-group 7]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -1 [set boarding-group 8]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 1 [set boarding-group 9]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 3 [set boarding-group 10]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 5 [set boarding-group 11]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 7 [set boarding-group 12]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 9 [set boarding-group 13]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 11 [set boarding-group 14]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -15 [set boarding-group 15]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -13 [set boarding-group 16]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -11 [set boarding-group 17]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -9 [set boarding-group 18]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -7 [set boarding-group 19]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -5 [set boarding-group 20]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -3 [set boarding-group 21]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -1 [set boarding-group 22]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 1 [set boarding-group 23]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 3 [set boarding-group 24]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 5 [set boarding-group 25]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 7 [set boarding-group 26]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 9 [set boarding-group 27]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 11 [set boarding-group 28])]
      plane-type = "double-aisle" [
        set max-boarding-group 42
        (ifelse
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -15 [set boarding-group 1]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -13 [set boarding-group 2]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -11 [set boarding-group 3]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -9 [set boarding-group 4]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -7 [set boarding-group 5]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -5 [set boarding-group 6]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -3 [set boarding-group 7]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = -1 [set boarding-group 8]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 1 [set boarding-group 9]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 3 [set boarding-group 10]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 5 [set boarding-group 11]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 7 [set boarding-group 12]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 9 [set boarding-group 13]
          [section] of desired-seat = 1 and [pxcor] of desired-seat = 11 [set boarding-group 14]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -15 [set boarding-group 15]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -13 [set boarding-group 16]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -11 [set boarding-group 17]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -9 [set boarding-group 18]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -7 [set boarding-group 19]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -5 [set boarding-group 20]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -3 [set boarding-group 21]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = -1 [set boarding-group 22]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 1 [set boarding-group 23]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 3 [set boarding-group 24]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 5 [set boarding-group 25]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 7 [set boarding-group 26]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 9 [set boarding-group 27]
          [section] of desired-seat = 2 and [pxcor] of desired-seat = 11 [set boarding-group 28]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = -15 [set boarding-group 29]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = -13 [set boarding-group 30]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = -11 [set boarding-group 31]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = -9 [set boarding-group 32]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = -7 [set boarding-group 33]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = -5 [set boarding-group 34]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = -3 [set boarding-group 35]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = -1 [set boarding-group 36]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = 1 [set boarding-group 37]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = 3 [set boarding-group 38]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = 5 [set boarding-group 39]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = 7 [set boarding-group 40]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = 9 [set boarding-group 41]
          [section] of desired-seat = 3 and [pxcor] of desired-seat = 11 [set boarding-group 42])])]
end

to assign-back-to-front-by-seating-order ; turtle procedure
  ask turtles [
    (ifelse
      plane-type = "single-aisle" [
        set max-boarding-group 84
        (ifelse
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -15 [set boarding-group 1]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -14 [set boarding-group 3]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -13 [set boarding-group 5]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -11 [set boarding-group 6]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -10 [set boarding-group 4]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -9 [set boarding-group 2]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -15 [set boarding-group 7]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -14 [set boarding-group 9]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -13 [set boarding-group 11]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -11 [set boarding-group 12]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -10 [set boarding-group 10]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -9 [set boarding-group 8]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -15 [set boarding-group 13]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -14 [set boarding-group 15]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -13 [set boarding-group 17]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -11 [set boarding-group 18]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -10 [set boarding-group 16]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -9 [set boarding-group 14]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -15 [set boarding-group 19]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -14 [set boarding-group 21]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -13 [set boarding-group 23]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -11 [set boarding-group 24]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -10 [set boarding-group 22]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -9 [set boarding-group 20]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -15 [set boarding-group 25]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -14 [set boarding-group 27]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -13 [set boarding-group 29]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -11 [set boarding-group 30]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -10 [set boarding-group 28]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -9 [set boarding-group 26]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -15 [set boarding-group 31]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -14 [set boarding-group 33]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -13 [set boarding-group 35]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -11 [set boarding-group 36]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -10 [set boarding-group 34]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -9 [set boarding-group 32]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -15 [set boarding-group 37]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -14 [set boarding-group 39]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -13 [set boarding-group 41]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -11 [set boarding-group 42]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -10 [set boarding-group 40]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -9 [set boarding-group 38]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -15 [set boarding-group 43]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -14 [set boarding-group 45]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -13 [set boarding-group 47]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -11 [set boarding-group 48]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -10 [set boarding-group 46]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -9 [set boarding-group 44]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -15 [set boarding-group 49]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -14 [set boarding-group 51]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -13 [set boarding-group 53]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -11 [set boarding-group 54]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -10 [set boarding-group 52]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -9 [set boarding-group 50]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -15 [set boarding-group 55]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -14 [set boarding-group 57]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -13 [set boarding-group 59]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -11 [set boarding-group 60]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -10 [set boarding-group 58]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -9 [set boarding-group 56]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -15 [set boarding-group 61]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -14 [set boarding-group 63]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -13 [set boarding-group 65]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -11 [set boarding-group 66]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -10 [set boarding-group 64]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -9 [set boarding-group 62]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -15 [set boarding-group 67]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -14 [set boarding-group 69]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -13 [set boarding-group 71]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -11 [set boarding-group 72]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -10 [set boarding-group 70]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -9 [set boarding-group 68]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -15 [set boarding-group 73]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -14 [set boarding-group 75]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -13 [set boarding-group 77]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -11 [set boarding-group 78]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -10 [set boarding-group 76]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -9 [set boarding-group 74]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -15 [set boarding-group 79]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -14 [set boarding-group 81]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -13 [set boarding-group 83]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -11 [set boarding-group 84]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -10 [set boarding-group 82]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -9 [set boarding-group 80])]
      plane-type = "double-aisle" [
        set max-boarding-group 126
        (ifelse
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -15 [set boarding-group 1]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -14 [set boarding-group 3]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -13 [set boarding-group 5]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -11 [set boarding-group 8]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -10 [set boarding-group 7]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -9 [set boarding-group 9]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -7 [set boarding-group 6]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -6 [set boarding-group 4]
          [pxcor] of desired-seat = -15 and [pycor] of desired-seat = -5 [set boarding-group 2]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -15 [set boarding-group 10]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -14 [set boarding-group 12]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -13 [set boarding-group 14]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -11 [set boarding-group 17]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -10 [set boarding-group 16]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -9 [set boarding-group 18]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -7 [set boarding-group 15]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -6 [set boarding-group 13]
          [pxcor] of desired-seat = -13 and [pycor] of desired-seat = -5 [set boarding-group 11]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -15 [set boarding-group 19]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -14 [set boarding-group 21]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -13 [set boarding-group 23]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -11 [set boarding-group 26]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -10 [set boarding-group 25]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -9 [set boarding-group 27]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -7 [set boarding-group 24]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -6 [set boarding-group 22]
          [pxcor] of desired-seat = -11 and [pycor] of desired-seat = -5 [set boarding-group 20]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -15 [set boarding-group 28]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -14 [set boarding-group 30]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -13 [set boarding-group 32]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -11 [set boarding-group 35]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -10 [set boarding-group 34]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -9 [set boarding-group 36]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -7 [set boarding-group 33]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -6 [set boarding-group 31]
          [pxcor] of desired-seat = -9 and [pycor] of desired-seat = -5 [set boarding-group 29]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -15 [set boarding-group 37]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -14 [set boarding-group 39]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -13 [set boarding-group 41]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -11 [set boarding-group 44]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -10 [set boarding-group 43]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -9 [set boarding-group 45]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -7 [set boarding-group 42]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -6 [set boarding-group 40]
          [pxcor] of desired-seat = -7 and [pycor] of desired-seat = -5 [set boarding-group 38]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -15 [set boarding-group 46]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -14 [set boarding-group 48]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -13 [set boarding-group 50]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -11 [set boarding-group 53]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -10 [set boarding-group 52]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -9 [set boarding-group 54]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -7 [set boarding-group 51]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -6 [set boarding-group 49]
          [pxcor] of desired-seat = -5 and [pycor] of desired-seat = -5 [set boarding-group 47]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -15 [set boarding-group 55]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -14 [set boarding-group 57]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -13 [set boarding-group 59]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -11 [set boarding-group 62]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -10 [set boarding-group 61]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -9 [set boarding-group 63]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -7 [set boarding-group 60]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -6 [set boarding-group 58]
          [pxcor] of desired-seat = -3 and [pycor] of desired-seat = -5 [set boarding-group 56]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -15 [set boarding-group 64]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -14 [set boarding-group 66]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -13 [set boarding-group 68]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -11 [set boarding-group 71]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -10 [set boarding-group 70]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -9 [set boarding-group 72]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -7 [set boarding-group 69]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -6 [set boarding-group 67]
          [pxcor] of desired-seat = -1 and [pycor] of desired-seat = -5 [set boarding-group 65]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -15 [set boarding-group 73]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -14 [set boarding-group 75]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -13 [set boarding-group 77]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -11 [set boarding-group 80]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -10 [set boarding-group 79]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -9 [set boarding-group 81]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -7 [set boarding-group 78]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -6 [set boarding-group 76]
          [pxcor] of desired-seat = 1 and [pycor] of desired-seat = -5 [set boarding-group 74]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -15 [set boarding-group 82]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -14 [set boarding-group 84]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -13 [set boarding-group 86]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -11 [set boarding-group 89]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -10 [set boarding-group 88]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -9 [set boarding-group 90]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -7 [set boarding-group 87]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -6 [set boarding-group 85]
          [pxcor] of desired-seat = 3 and [pycor] of desired-seat = -5 [set boarding-group 83]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -15 [set boarding-group 91]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -14 [set boarding-group 93]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -13 [set boarding-group 95]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -11 [set boarding-group 98]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -10 [set boarding-group 97]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -9 [set boarding-group 99]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -7 [set boarding-group 96]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -6 [set boarding-group 94]
          [pxcor] of desired-seat = 5 and [pycor] of desired-seat = -5 [set boarding-group 92]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -15 [set boarding-group 100]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -14 [set boarding-group 102]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -13 [set boarding-group 104]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -11 [set boarding-group 107]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -10 [set boarding-group 106]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -9 [set boarding-group 108]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -7 [set boarding-group 105]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -6 [set boarding-group 103]
          [pxcor] of desired-seat = 7 and [pycor] of desired-seat = -5 [set boarding-group 101]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -15 [set boarding-group 109]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -14 [set boarding-group 111]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -13 [set boarding-group 113]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -11 [set boarding-group 116]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -10 [set boarding-group 115]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -9 [set boarding-group 117]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -7 [set boarding-group 114]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -6 [set boarding-group 112]
          [pxcor] of desired-seat = 9 and [pycor] of desired-seat = -5 [set boarding-group 110]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -15 [set boarding-group 118]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -14 [set boarding-group 120]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -13 [set boarding-group 122]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -11 [set boarding-group 125]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -10 [set boarding-group 124]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -9 [set boarding-group 126]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -7 [set boarding-group 123]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -6 [set boarding-group 121]
          [pxcor] of desired-seat = 11 and [pycor] of desired-seat = -5 [set boarding-group 119])])]
end

to update-happinesses
  ask turtles [
    ; if they're in the airport, they get unhappy at a (slowest) rate
    if [ptype] of patch-here = "af"  [
      set happiness happiness - 0.5
    ]

    ; if they're in the bridge or aisle, they don't get unhappy
    ; justification: once they realize they are close to getting seated, they're okay

    ; if they're in the correct seat, they gain happiness for a while then lose happiness quickly
    ; justification: they're happy to be seated, but then get unhappy once they wait too long
    if [ptype] of patch-here = "s" and [pcolor] of patch-here = taken-seat  [
      ifelse seated-count < initial-happiness
      [set happiness happiness + 0.75]
      [set happiness happiness - 1]
      set seated-count seated-count + 1
    ]
  ]
end

to recolor-seats
  ; if someone is (correctly) sitting in the seat now, color it
  ask patches with [pcolor = free-seat] [
    if count turtles-here > 0 [
      if [desired-seat] of one-of turtles-here = self [
        set pcolor taken-seat
      ]
    ]
  ]
end

to create-passengers
  if plane-type = "single-aisle" [make-people 84 * percent-full]
  if plane-type = "double-aisle" [make-people 126 * percent-full]
end

to make-people [num-people]
  create-turtles num-people [
    set label-color black
    set time-out-of-seat 0
    set bag? random-float 1 < probability-carry-on
    set delay-time 0
    set shape "person"
    set happiness initial-happiness
    set seated-count 0
    set desired-seat one-of open-seats with [count turtles-here = 0]
    set desired-row patch ([pxcor] of desired-seat + 1) ([pycor] of desired-seat)
    ; "claim" your seat so that nobody else can desire your seat
    move-to desired-seat
    let ds desired-seat
    set my-row patches with [ptype = "s" and pxcor = [pxcor] of ds and section = [section] of ds]
    set color one-of skin-colors
  ]
  ; put the turtles back in the airport, in their own patch, now with a seat assignment
  ask turtles [
    move-to one-of patches with [count turtles-here = 0 and ptype = "as"]
  ]
end

to color-patches ; setup procedure
  create-grass
  create-airport
  (ifelse
    plane-type = "single-aisle" [ create-plane-3-3 ]
    plane-type = "double-aisle" [ create-plane-3-3-3 ])
  set open-seats patches with [pcolor = free-seat]
end

to create-grass ; first make everything green
  ask patches [
    set pcolor green
    set ptype "g"
  ]
end

to create-airport ; then begin to color the airport floor, walls, and seats
  ask patches with [pycor >= 0] [
    set pcolor 8
    set ptype "af"
  ]
  ask patches with [pxcor = 14 and pycor < 15 and pycor > 1] [
    set ptype "b"
  ]
  ask patches with [(pycor = 0 or pycor = 16) or (pycor > 0 and pycor < 16 and (pxcor = -16 or pxcor = 16))] [
    set pcolor black
    set ptype "w"
  ]

  ask patches with [((pycor = 4 or pycor = 5 or pycor = 8 or pycor = 9 or pycor = 12 or pycor = 13) and (-13 < pxcor and pxcor < 8))
    or (((pxcor = -15) and (16 > pycor and pycor > 1)) or ((pycor = 1) and (-15 < pxcor and pxcor < 8)))] [
    set pcolor 102
    set ptype "as"
  ]
  ask patch -15 1 [ set pcolor 102 set ptype "w" ]
end

to setup-globals
  (ifelse
    plane-type = "single-aisle" [ set initial-happiness 168 set boarding-wait-time 8]
    plane-type = "double-aisle" [ set initial-happiness 252 set boarding-wait-time 6])
  set taken-seat 57
  set free-seat 17
  set skin-colors [[138 84 59] [141 85 36] [198 134 66] [224 172 105] [241 194 125] [255 219 172]]
  set current-boarding-group -1
end

to create-plane-3-3 ; creates everything for a single-aisle plane
  ;; setup plane border
  ask patches with [(pycor = -16) or (pycor = -8) and (pxcor < 16)] [set pcolor white  set ptype "w"]
  ask patches with [(pxcor = 15 or pxcor = -16) and (pycor > -16) and (pycor < -8)] [set pcolor white  set ptype "w"]

  ;; setup plane background
  ask patches with [(pxcor < 15) and (pxcor > -16) and (pycor > -16) and (pycor < -8)] [set pcolor 107  set ptype "pf"]

  ;; set up "rows"
  ask patches with [pxcor <= 12 and pcolor = 107] [set ptype "r"]

  ;; setup seats
  ask patches with [((pxcor = -15) or (pxcor = -13) or (pxcor = -11) or (pxcor = -9) or (pxcor = -7) or
    (pxcor = -5) or (pxcor = -3) or (pxcor = -1) or (pxcor = 1) or (pxcor = 3) or (pxcor = 5) or
    (pxcor = 7) or (pxcor = 9) or (pxcor = 11)) and ((pycor = -15) or (pycor = -14) or (pycor = -13) or
    (pycor = -11) or (pycor = -10) or (pycor = -9))] [
    (ifelse
      pycor = -15 [set section 2 set seat-type "window" set correct-aisle -12 set ptype "s" set pcolor free-seat]
      pycor = -14 [set section 2 set seat-type "middle" set correct-aisle -12 set ptype "s" set pcolor free-seat]
      pycor = -13 [set section 2 set seat-type "aisle" set correct-aisle -12 set ptype "s" set pcolor free-seat]
      pycor = -11 [set section 1 set seat-type "aisle" set correct-aisle -12 set ptype "s" set pcolor free-seat]
      pycor = -10 [set section 1 set seat-type "middle" set correct-aisle -12 set ptype "s" set pcolor free-seat]
      pycor = -9 [set section 1 set seat-type "window" set correct-aisle -12 set ptype "s" set pcolor free-seat])
    (ifelse
      -16 < pxcor and pxcor <= -11 [set zone 1]
      -11 < pxcor and pxcor <= -5 [set zone 2]
      -5 < pxcor and pxcor <= 1 [set zone 3]
      1 < pxcor and pxcor <= 7 [set zone 4]
      7 < pxcor and pxcor <= 16 [set zone 5])
  ]

  ;; create jetbridge to airport
  ask patches with [((pxcor = 15) or (pxcor = 13)) and ((pycor <= 0) and (pycor > -8))] [set pcolor black  set ptype "w"]
  ask patches with [(pxcor = 14) and ((pycor <= 1) and (pycor > -8))] [set pcolor 8  set ptype "b"]
  ask patch 14 -8 [set pcolor 8  set ptype "b"]

  ;; designate the aisle
  ask patches with [pycor = -12 and pcolor = 107] [ set ptype "a" ]

  ;; bug fix?
  ask patches with [pxcor = 13 and (pycor = -9 or pycor = -10 or  pycor = -11)] [set ptype "w"]
end

to create-plane-3-3-3 ; creates everything for a double-aisle plane
  ;; setup plane border
  ask patches with [(pycor = -16) or (pycor = -4) and (pxcor < 16)] [set pcolor white  set ptype "w"]
  ask patches with [(pxcor = 15 or pxcor = -16) and (pycor > -16) and (pycor < -4)] [set pcolor white  set ptype "w"]

  ;; setup plane background
  ask patches with [(pxcor < 15) and (pxcor > -16) and (pycor > -16) and (pycor < -4)] [set pcolor 107  set ptype "pf"]

  ;; set up "rows"
  ask patches with [pxcor <= 12 and pcolor = 107] [set ptype "r"]

  ;; setup seats
  ask patches with [((pxcor = -15) or (pxcor = -13) or (pxcor = -11) or (pxcor = -9) or (pxcor = -7) or
    (pxcor = -5) or (pxcor = -3) or (pxcor = -1) or (pxcor = 1) or (pxcor = 3) or (pxcor = 5) or
    (pxcor = 7) or (pxcor = 9) or (pxcor = 11)) and ((pycor = -15) or (pycor = -14) or (pycor = -13) or
    (pycor = -11) or (pycor = -10) or (pycor = -9) or (pycor = -7) or (pycor = -6) or (pycor = -5))] [
    (ifelse
      pycor = -15 [set section 3 set seat-type "window" set correct-aisle -12 set ptype "s" set pcolor free-seat]
      pycor = -14 [set section 3 set seat-type "middle" set correct-aisle -12 set ptype "s" set pcolor free-seat]
      pycor = -13 [set section 3 set seat-type "aisle" set correct-aisle -12 set ptype "s" set pcolor free-seat]
      pycor = -11 [set section 2 set seat-type "aisle" set correct-aisle -12 set ptype "s" set pcolor free-seat]
      pycor = -10 [set section 2 set seat-type "middle" set correct-aisle one-of (list -12 -8) set ptype "s" set pcolor free-seat]
      pycor = -9 [set section 2 set seat-type "aisle" set correct-aisle -8 set ptype "s" set pcolor free-seat]
      pycor = -7 [set section 1 set seat-type "aisle" set correct-aisle -8 set ptype "s" set pcolor free-seat]
      pycor = -6 [set section 1 set seat-type "middle" set correct-aisle -8 set ptype "s" set pcolor free-seat]
      pycor = -5 [set section 1 set seat-type "window" set correct-aisle -8 set ptype "s" set pcolor free-seat])
    (ifelse
      -16 < pxcor and pxcor <= -11 [set zone 1]
      -11 < pxcor and pxcor <= -5 [set zone 2]
      -5 < pxcor and pxcor <= 1 [set zone 3]
      1 < pxcor and pxcor <= 7 [set zone 4]
      7 < pxcor and pxcor <= 16 [set zone 5])
  ]

  ;; create jetbridge to airport
  ask patches with [((pxcor = 15) or (pxcor = 13)) and ((pycor <= 0) and (pycor > -4))] [set pcolor black set ptype "w"]
  ask patches with [(pxcor = 14) and ((pycor <= 1) and (pycor > -4))] [set pcolor 8 set ptype "b"]
  ask patch 14 -4 [set pcolor 8 set ptype "b"]

  ;; designate the aisle
  ask patches with [(pycor = -12 or pycor = -8) and pcolor = 107] [ set ptype "a" ]

  ;; bug fix?
  ask patches with [pxcor = 13 and (pycor = -7 or pycor = -5 or  pycor = -6)] [set ptype "w"]
end
@#$#@#$#@
GRAPHICS-WINDOW
265
10
858
604
-1
-1
17.73
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
5
10
128
43
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
5
120
255
165
plane-type
plane-type
"single-aisle" "double-aisle"
1

BUTTON
130
10
253
43
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
5
455
255
605
happiness
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [happiness] of turtles * 100 / initial-happiness"

SLIDER
5
50
255
83
probability-carry-on
probability-carry-on
0
1
1.0
0.01
1
NIL
HORIZONTAL

CHOOSER
5
170
255
215
boarding-strategy
boarding-strategy
"random" "WilMA" "back-to-front-5-zones" "half-block-back-to-front" "half-block-mix-1" "half-block-mix-2" "by-row-back-to-front" "by-half-row-back-to-front" "back-to-front-by-seating-order"
0

SLIDER
5
85
255
118
percent-full
percent-full
0
1
1.0
0.01
1
NIL
HORIZONTAL

MONITOR
5
305
255
350
average time out of seat
mean [time-out-of-seat] of turtles
0
1
11

MONITOR
5
355
255
400
max time out of seat
max [time-out-of-seat] of turtles
17
1
11

SWITCH
5
220
255
253
label-boarding-groups?
label-boarding-groups?
0
1
-1000

MONITOR
5
255
255
300
current boarding group
current-boarding-group
17
1
11

MONITOR
5
405
255
450
average happiness
mean [happiness] of turtles * 100 / initial-happiness
0
1
11

@#$#@#$#@
## WHAT IS IT?

This model is inspired by the process of boarding an airplane, which many people frequently occur during travel but might not think about. Specifically, it aims to model the overall happiness of passengers and the total time taken to board the plane. The boarding strategies and overall use of the model is based on an article written [Delcea and colleagues](https://www.mdpi.com/2071-1050/10/6/1879/htm). 

Airplane boarding has many different strategies, and there are many variables involved beyond the boarding strategy such as the full-ness of the airplane, the seating configuration of the plane, and the quantity of people putting carry-on bags in the overhead bins.

## HOW IT WORKS

This model creates an airport with attached airplane and people seated in the airport waiting to board the plane. Each person has an assigned seat and a boarding group based on their seat and the boarding strategy. At each tick, the people move towards their seats when it is their turn. If there is someone in the patch they'd like to move to, they of course must wait for the person to vacate that patch.

As they wait in the airport, they get unhappy, but at a slow rate. They are comfortable, can stretch out their legs, and aren't cramped yet. When they get onto the plane, they are initially happy and gain happiness because of their excitement and anticipation over the upcoming flight. If they have been waiting on the plane for too long, they begin to get unhappy at a higher rate. They are tired of being cramped and want to either get off the plane or get into the air.

## HOW TO USE IT

1. Set the probability of each passenger having a carry-on bag
2. Select how full the airplane will be
3. Choose a type of plane
4. Choose a boarding strategy
5. Press the SETUP button
6. Press the GO button
7. Watch the people move onto the plane, noting any bottlenecks in the system
8. Watch the plots and monitors to see how people are happy and unhappy
9. Try again with tweaked paramaters

### Parameters
PROBABILITY-CARRY-ON: The probability any passenger will have a carry-on bag
PERCENT-FULL: The percentage of available seats that will be filled by passengers
PLANE-TYPE: The seating configuration of the airplane to try to board
BOARDING-STRATEGY: The strategy (by assigning groups) of getting the people on the plane

### Plots and Monitors

HAPPINESS: The percentage of the original happiness had by the passengers remaining in the system
AVERAGE TIME OUT OF SEAT: The average amount of time a turtle in the system has spent between their airport seat and airplane seat
MAX TIME OUT OF SEAT: The maximum amount of time any turtle in the system has spent between their airport seat and airplane seat

## THINGS TO NOTICE

Notice the fluctuations in average happiness as the people board the plane. Does it always strictly increase or decrease? Why might that be?

Notice when people get backed up in a queue. What does that do to the boarding process? What individual turtle-level behaviors are causing this?



## THINGS TO TRY

Try choosing 2 or 3 boarding strategies that you like. Run them on different airplane models. Is one always best? Worst?

Try altering the baggage probability and full-ness of the plane. How does this affect the results? Is it always expected?

## EXTENDING THE MODEL

Could we add more (or event a custom) boarding strategy?

Could you add people going to the wrong seat? 

Could you add elite members, families, military members, etc. that always needed to board early and potentially would be sitting together?


## CREDITS AND REFERENCES

This model was based on research done and boarding strategies used in this aricle:

Delcea, Camelia and Cotfas, Liviu-Adrian and Paun, Ramona. "Agent-Based Evaluation of the Airplane Boarding Strategies’ Efficiency and Sustainability." Sustainability, 10, 6, 2018.

https://www.mdpi.com/2071-1050/10/6/1879/htm
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="final-model-data" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <exitCondition>count patches with [pcolor = taken-seat] = count turtles</exitCondition>
    <metric>mean [happiness] of turtles * 100 / initial-happiness</metric>
    <metric>max [time-out-of-seat] of turtles</metric>
    <metric>mean [time-out-of-seat] of turtles</metric>
    <enumeratedValueSet variable="probability-carry-on">
      <value value="0"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding-strategy">
      <value value="&quot;random&quot;"/>
      <value value="&quot;WilMA&quot;"/>
      <value value="&quot;back-to-front-5-zones&quot;"/>
      <value value="&quot;half-block-back-to-front&quot;"/>
      <value value="&quot;half-block-mix-1&quot;"/>
      <value value="&quot;half-block-mix-2&quot;"/>
      <value value="&quot;by-row-back-to-front&quot;"/>
      <value value="&quot;by-half-row-back-to-front&quot;"/>
      <value value="&quot;back-to-front-by-seating-order&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plane-type">
      <value value="&quot;single-aisle&quot;"/>
      <value value="&quot;double-aisle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="label-boarding-groups?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percent-full">
      <value value="0.7"/>
      <value value="0.8"/>
      <value value="0.9"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
