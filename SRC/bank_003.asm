; Disassembly of "Metroid2.gb"
; This file was created with:
; mgbdis v1.4 - Game Boy ROM disassembler by Matt Currie and contributors.
; https://github.com/mattcurrie/mgbdis

SECTION "ROM Bank $003", ROMX[$4000], BANK[$3]

handleEnemyLoading: ;{ 03:4000
    call loadEnemies
    ; Update scroll history
    ; y2 <= y1
    ld hl, scrollHistory_B.y1
    ld a, [hl-]
    ld [hl+], a
    ; y1 <= y0
    ld a, [scrollY]
    ld [hl+], a
    ; x2 <= x1
    inc l
    ld a, [hl-]
    ld [hl+], a
    ; x1 <= x0
    ld a, [scrollX]
    ld [hl], a
ret ;}

; Handles loading enemies from the map
;  Alternates between vertical and horizontal checks
;  Has some weird optimizations that make certain assumptions of the underlying order of the data
loadEnemies: ;{ 03:4014
    ; Load y pixel to L
    ld de, hCameraYPixel
    ld a, [de]
    ld l, a
    ; Load y screen to H
    inc e
    ld a, [de]
    ld h, a
    push hl
        ; Get bottom edge of the visible screen, rounded to the nearest block
        ld bc, $68 ;$0068
        add hl, bc
        ld a, l
        and $f0
        ld [bottomEdge_pixel], a
        ld a, h
        ld [bottomEdge_screen], a
    pop hl
    ; Get top edge of visible screen, rounded to the nearest block
    ld bc, -$58 ;$ffa8
    add hl, bc
    ld a, l
    and $f0
    ld [topEdge_pixel], a
    ld a, h
    ld [topEdge_screen], a
    
    ; Load x pixel to L
    inc e
    ld a, [de]
    ld l, a
    ; Load x screen to H
    inc e
    ld a, [de]
    ld h, a
    push hl
        ; Get right edge of the visible screen, rounded to the nearest tile
        ld bc, $68 ;$0068
        add hl, bc
        ld a, l
        and $f8
        ld [rightEdge_pixel], a
        ld a, h
        ld [rightEdge_screen], a
    pop hl
    ; Get left edge of the visible screen, rounded to the nearest tile
    ld bc, -$60 ;$ffa0 - Just a negative number, not sprite DMA related
    add hl, bc
    ld a, l
    and $f8
    ld [leftEdge_pixel], a
    ld a, h
    ld [leftEdge_screen], a
    
    ld d, $ff
    ; Prevent enemies from loading via vertical wraparound of the map
    ld a, [bottomEdge_screen]
    ld b, a
    and $0f
    jr nz, .endIf_A
        ld a, [topEdge_screen]
        ld c, a
        and $0f
        cp $0f
        jr nz, .endIf_A
            ; We get to this point if the bottom edge of the screen is on the top screen
            ;  and the top edge of the screen on the bottom screen
            
            ; Check if the center of the screen is above or below the seam
            ld a, [hCameraYScreen]
            cp b
            jr z, .else_B
                ; Clamp bottom edge of screen to the bottom edge of the map
                ld a, c ; C = topEdge_screen
                ld [bottomEdge_screen], a
                ld a, d ; D is $FF
                ld [bottomEdge_pixel], a
                jr .endIf_A
            .else_B:
                ; Clamp top edge of screen to the top edge of the map
                ld a, b ; B = bottomEdge_screen
                ld [topEdge_screen], a
                xor a
                ld [topEdge_pixel], a
    .endIf_A:

    ; Prevent enemies from loading via horizontal wraparound of the map
    ld a, [rightEdge_screen]
    ld b, a
    and $0f
    jr nz, .endIf_C
        ld a, [leftEdge_screen]
        ld c, a
        and $0f
        cp $0f
        jr nz, .endIf_C
            ; We get to this point if the right edge of the screen is on the leftmost screen
            ;  and the left edge of the screen on the rightmost screen.
        
            ; Check if the center of the screen is to the left or right of the seam
            ld a, [hCameraXScreen]
            cp b
            jr z, .else_D
                ; Clamp right edge of screen to the right edge of the map
                ld a, c ; C = leftEdge_screen
                ld [rightEdge_screen], a
                ld a, d ; D is $FF
                ld [rightEdge_pixel], a
                jr .endIf_C
            .else_D:
                ; Clamp left edge of the screen to the left edge of the map
                ld a, b ; B = rightEdge_screen
                ld [leftEdge_screen], a
                xor a
                ld [leftEdge_pixel], a
    .endIf_C:

    ; Switch between loading enemies horizontally and vertically every frame
    ld hl, loadEnemies_oscillator
    ld a, [hl]
    xor $01
    ld [hl], a
jp z, loadEnemies_horizontal ;}

; Vertical case to the above function
loadEnemies_vertical: ;{ 03:40BE
    ; Compare scroll value between now and two frames ago, exit if equal
    ld hl, scrollHistory_B.y2
    ld a, [scrollY]
    sub [hl]
        ret z

    jr c, .else_A
        ; Get bottom left corner
        ld a, $01
        ld [loadEnemies_unusedVar], a
        ld a, [bottomEdge_screen]
        ld b, a
        ld a, [leftEdge_screen]
        ld c, a
        ld a, [bottomEdge_pixel]
        ld [hTemp.a], a
        call loadEnemy_getBankOffset
        call loadEnemy_getPointer.screen
        jr .endIf_A
    .else_A:
        ; Get top-left corner
        ld a, $03
        ld [loadEnemies_unusedVar], a
        ld a, [topEdge_screen]
        ld b, a
        ld a, [leftEdge_screen]
        ld c, a
        ld a, [topEdge_pixel]
        ld [hTemp.a], a
        call loadEnemy_getBankOffset
        call loadEnemy_getPointer.screen
    .endIf_A:

; Check left screen {
    .left_nextEnemy:
        ; Load sprite type, move on to next screen if $FF
        ld a, [hl]
        cp $ff
            jr z, .checkRightScreen
        ; Load sprite number
        ld a, [hl+]
        ld e, a
        ; Check if spawn flag is active or dead
        ld d, HIGH(enemySpawnFlags)
        ld a, [de]
        cp $fe
            jr nc, .left_loadEnemy
        inc hl ; Set HL to xpos
      .left_skipY:
        inc hl ; Set HL to ypos
      .left_skipToNext:
        inc hl ; Set HL to next enemy
    jr .left_nextEnemy

.left_loadEnemy:
    ; Load x
    inc hl
    ld a, [hl]
    and $f8 ; Clamp to nearest tile
    ld e, a
    ; Compare with left edge of screen
    ld a, [leftEdge_pixel]
    cp e ; Skip to next enemy if it is not to the right side of the seam
        jr nc, .left_skipY
    ld d, a
    
    ; If the right edge pixel value has a greater value than the left edge pixel value
    ;  (i.e. the camera does not cross a screen boundary)
    ; AND the enemy x pixel is to the right of the right edge of the screen
    ;  then exit
    ld a, [rightEdge_pixel]
    cp d
    jr c, .endIf_B
        cp e
        ret c
    .endIf_B:
    
    ; Load y
    inc hl
    ld a, [hl]
    and $f0 ; Clamp to nearest block
    ld e, a
    ; If the clamped enemy Y equals the clamped camera Y
    ;  then load the enemy
    ld a, [hTemp.a]
    cp e
    jr z, .endIf_C
        jr .left_skipToNext
    .endIf_C:
    
    call loadOneEnemy
jr .left_skipToNext ;}

.checkRightScreen: ;{
    ; Iterate to next screen lazily, by assuming its enemy data is contiguous with the previous
    inc hl
    ; Compare left screen to right screen
    ld a, [rightEdge_screen]
    cp c
        ret z ; Exit if they are equal
        ret c ; Exit if there is wraparound

    .right_nextEnemy:
        ; Load sprite type, exit if it is $FF
        ld a, [hl]
        cp $ff
            ret z
        ; Load sprite number
        ld a, [hl+]
        ld e, a
        ; Check if spawn flag is active or dead
        ld d, HIGH(enemySpawnFlags)
        ld a, [de]
        cp $fe
            jr nc, .right_loadEnemy
        inc hl ; Set HL to xpos
        inc hl ; Set HL to ypos
      .right_skipToNext:
        inc hl ; Set HL to next enemy
    jr .right_nextEnemy

.right_loadEnemy:
    ; Load x pos
    inc hl
    ld a, [hl]
    and $f8 ; Clamp to nearest tile
    ld e, a
    ld a, [rightEdge_pixel]
    cp e ; Exit if enemy is not to the left side of the right edge
        ret c ; Why does this not go to .right_skipY like the previous case?
    
    ; Load y pos
    inc hl
    ld a, [hl]
    and $f0 ; Clamp to nearest block
    ld e, a
    ; If the clamped enemy Y equals the clamped camera Y
    ;  then load the enemy
    ld a, [hTemp.a]
    cp e
    jr z, .endIf_D
        jr .right_skipToNext
    .endIf_D:
    
    call loadOneEnemy
jr .right_skipToNext ;}
;} End vertical case

; Horizontal case to the above function
loadEnemies_horizontal: ;{ 03:416A
    ld hl, scrollHistory_B.x2
    ld a, [scrollX]
    sub [hl]
        ret z

    jr c, .else_A
        ; Get top-right corner
        ld a, $00
        ld [loadEnemies_unusedVar], a
        ld a, [topEdge_screen]
        ld b, a
        ld a, [rightEdge_screen]
        ld c, a
        ld [loadEnemy_unusedVar_B], a
        ld a, [rightEdge_pixel]
        ld [hTemp.a], a
        call loadEnemy_getBankOffset
        call loadEnemy_getPointer.screen
        jr .endIf_A
    .else_A:
        ; Get top-left corner
        ld a, $01
        ld [loadEnemies_unusedVar], a
        ld a, [topEdge_screen]
        ld b, a
        ld a, [leftEdge_screen]
        ld c, a
        ld a, [leftEdge_pixel]
        ld [hTemp.a], a
        call loadEnemy_getBankOffset
        call loadEnemy_getPointer.screen
    .endIf_A:

; Check top screen {
    .top_nextEnemy:
        ; Load sprite type, move on to next screen if $FF
        ld a, [hl]
        cp $ff
            jr z, .checkBottomScreen
        ; Check if spawn flag is active or dead
        ld a, [hl+]
        ld e, a
        ld d, HIGH(enemySpawnFlags)
        ld a, [de]
        cp $fe
            jr nc, .top_loadEnemy
        inc hl ; Set HL to xpos
      .top_skipY:
        inc hl ; Set HL to ypos
      .top_skipToNext:
        inc hl ; Set HL to next enemy
    jr .top_nextEnemy

.top_loadEnemy:
    ; Load x pos
    inc hl
    ld a, [hl]
    and $f8 ; Clamp to nearest tile
    ld e, a
    ; Compare enemy x to seam
    ld a, [hTemp.a]
    cp e
    jr z, .endIf_B ; If equal, try loading
        jr nc, .top_skipY ; If enemy is to the left of the seam, skip to next enemy
        jr .checkBottomScreen ; else (implicitly to the right), skip to the next screen
        ; (...that's a weird optimization that implies a certain spatial structuring to the data)
    .endIf_B:

    ; Load y pos
    inc hl
    ld a, [hl]
    and $f0 ; Clamp to nearest block
    ld e, a
    ; If y pos does not equal top edge, skip to next enemy
    ld a, [topEdge_pixel]
    cp e
    jr z, .endIf_C
        jr nc, .top_skipToNext
    .endIf_C:
    ld d, a
    
    ; If the bottom edge pixel value is greater than the top edge pixel value
    ;  (i.e a screen boundary is not being crossed)
    ; AND the enemy is below the bottom edge of the camera
    ;  then skip to the next enemy
    ld a, [bottomEdge_pixel]
    cp d
    jr c, .endIf_D
        cp e
        jr c, .top_skipToNext
    .endIf_D:

    ; Load enemy
    call loadOneEnemy
jr .top_skipToNext ;}

.checkBottomScreen: ;{
    ; Check if the bottom and top screen are the same, exit if so
    ld a, [topEdge_screen]
    ld b, a
    inc b
    ld a, [bottomEdge_screen]
    cp b
        ret nz
    ; Iterate to the bottom screen (properly)
    ld a, c
    ld [loadEnemy_unusedVar_A], a
    call loadEnemy_getBankOffset
    call loadEnemy_getPointer.screen

    .bottom_nextEnemy:
        ; Load sprite type, move on to next screen if $FF
        ld a, [hl]
        cp $ff
            ret z
        ; Check if spawn flag is active or dead
        ld a, [hl+]
        ld e, a
        ld d, HIGH(enemySpawnFlags)
        ld a, [de]
        cp $fe
            jr nc, .bottom_loadEnemy
        inc hl ; Set HL to xpos
      .bottom_skipY:
        inc hl ; Set HL to ypos
      .bottom_skipToNext:
        inc hl ; Set HL to next enemy
    jr .bottom_nextEnemy

.bottom_loadEnemy:
    ; Load x pos
    inc hl
    ld a, [hl]
    and $f8 ; Clamp to nearest tile
    ld e, a
    ; Compare camera x to enemy x
    ld a, [hTemp.a]
    cp e ; Exit if enemy is to the right of the seam
        ret c
    ; Skip to next enemy if positions aren't equal
    jr z, .endIf_E
        jr .bottom_skipY
    .endIf_E:
    
    ; Load y pos
    inc hl
    ld a, [hl]
    and $f0 ; Clamp to nearest block
    ld e, a
    ; Compare enemy y to camera y
    ld a, [bottomEdge_pixel]
    cp e
    ; Skip to next enemy if it is below the camera edge
    jr nc, .endIf_F
        jr .bottom_skipToNext
    .endIf_F:

    call loadOneEnemy
jr .bottom_skipToNext ;}
;} End horizontal case

; Load one enemy
loadOneEnemy: ;{ 03:422F
    push bc
    ld d, h
    ld e, l
    call findFirstEmptyEnemySlot
    ld a, l
    ld [enemy_pWramLow], a
    ld a, h
    ld [enemy_pWramHigh], a
    xor a
    ld [hl+], a
    push de
    
    ld a, [scrollY]
    ld b, a
    ld a, [de]
    add $10
    sub b
    ld [hl+], a
    ld a, [scrollX]
    ld b, a
    dec de
    ld a, [de]
    add $08
    sub b
    ld [hl+], a
    dec de
    ld a, [de]
    ld [hl], a
    ld a, l
    add $1a
    ld l, a
    dec de
    ld a, [de]
    ld [hl], a ; Write enemy spawn number to enemy entry in RAM
    
    ld hl, enemySpawnFlags
    ld l, a
    ld a, [hl]
    cp $ff
    jr z, .else
        ld a, $04
        ld [hl], a
        ld [$c461], a
        jr .endIf
    .else:
        ld a, $01
        ld [hl], a
        ld [$c461], a
    .endIf:

    ld a, [enemy_pWramLow]
    add $03
    ld l, a
    ld a, [enemy_pWramHigh]
    ld h, a
    ld a, [hl+]
    push hl
        ld hl, enemyHeaderPointers
        call loadEnemy_getPointer.header
    pop hl
    
    ld b, $09
    .loadLoop: ; Read enemy header
        ld a, [de]
        ld [hl+], a
        inc de
        dec b
    jr nz, .loadLoop
    ld c, a
    
    xor a
    ld b, $04
    .clearLoop: ; Clear next few bytes
        ld [hl+], a
        dec b
    jr nz, .clearLoop

    ld [hl], c
    ld a, [enemy_pWramLow]
    add $1c
    ld l, a
    ld a, [$c461]
    ld [hl], a
    inc l
    inc l
    ld a, [de]
    ld [hl+], a
    inc de
    ld a, [de]
    ld [hl], a
    ld hl, numEnemies
    inc [hl]
    inc l
    inc [hl]
    
    pop de
    ld l, e
    ld h, d
    pop bc
ret ;}

; returns pointer to first unused enemy slot in HL
; WARNING: Does not perform any bounds check
findFirstEmptyEnemySlot: ;{ 03:42B4
    ld hl, enemyDataSlots
    ld bc, $0020
    .findLoop:
        ld a, [hl]
        cp $ff ; Exit with address if enemy is inactive
            ret z
        add hl, bc
    jr .findLoop
;}

; Returns the base offset for a bank's enemy data pointer in HL
loadEnemy_getBankOffset: ;{ 03:42C1
    ; HL = (levelBank-9)*$200
    ld hl, enemyDataPointers
    ld a, [currentLevelBank]
    sub $09 ; Adjust pointer to account for $9 being the first level bank
    add a
    ld d, a
    ld e, $00
    add hl, de
ret ;}

; Multiple entry points for loading an enemy map data pointer and and an enemy header pointer
loadEnemy_getPointer:
  .screen: ;{ 03:42CF
    ; Get index from YX coordinate
    ld a, b
    swap a
    add c
; Given a base offset in hl and a pointer index in a, returns a pointer in hl
  .header: ; 03:42D3
    ; HL =+ A*2
    ld d, $00
    add a
    rl d
    ld e, a
    add hl, de
    ; HL = [HL]
    ld e, [hl]
    inc hl
    ld d, [hl]
    ld h, d
    ld l, e
ret ;}

; Enemy Data starts here
enemyDataPointers:
	include "maps/enemyData.asm"

; 03:6244 -- Enemy Data ends here
; Freespace filled with $00 (NOP)

SECTION "ROM Bank $003 Part 2", ROMX[$6300], BANK[$3]
enemyHeaderPointers: ; 03:6300 - Enemy headers
    include "data/enemyHeaders.asm"
enemyDamageTable: ; 03:673A - Enemy damage values
    include "data/enemyDamage.asm"
enemyHitboxPointers: ; 03:6839 - Enemy hitboxes
    include "data/enemyHitboxes.asm"

; Enemy AI stuff

; Deletes the enemy currently loaded in HRAM
enemy_deleteSelf: ;{ 03:6AE7
    ld hl, hEnemyWorkingHram ; $FFE0
    ; Save hEnemyStatus to C
    ld c, [hl]
    ; Clear first 15 bytes of enemy data in HRAM
    ld a, $ff
    ld b, $0f
    .clearLoop:
        ld [hl+], a
        dec b
    jr nz, .clearLoop

    ; Read hEnemySpawnFlag to see if enemy has a parent
    ld a, [hl]
    and $0f
    jr nz, .endIf_A
        ; Get address of parent object from link in hEnemySpawnFlag
        ld a, [hl]
        ld h, HIGH(enemyDataSlots)
        bit 4, a
        jr nz, .else_B
            add $1c
            ld l, a
            jr .endIf_B
        .else_B:
            add $0c
            ld l, a
            inc h ; $C700 address
        .endIf_B:

        ; Check the enemy spawn flag of the parent
        ; If 3, set to 1
        ; If 5, set to 4
        ; Do this so their projectile-firing status is not saved
        ld a, [hl]
        cp $03 ; Deactivated because of child
        jr z, .else_C
            cp $05 ; ??
                jr nz, .endIf_A
            ld a, $04 ; ??
            jr .endIf_C
        .else_C:
            ld a, $01 ; Active
        .endIf_C:        
        ld [hl+], a
        
        ld b, a
        ld a, [hl]
        ld hl, enemySpawnFlags
        ld l, a
        ld [hl], b
    .endIf_A:

    ; Clear enemy AI pointer, and screen coordinates
    ld hl, hEnemyAI_low
    ld a, $ff
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld [hl], a
    ; Decrement number of total enemies and number of active enemies
    ld hl, numEnemies
    dec [hl]
    inc l
    dec [hl]
    ; Check if $C468 = $FFFD
    ld hl, $c468
    ld de, hEnemyWramAddrHigh
    ld a, [de]
    cp [hl]
        ret nz
    ; Check if $C467 = $FFFE
    dec e
    dec l
    ld a, [de]
    cp [hl]
        ret nz
    ; Clear $C466, $C467, $C468, $C469
    dec l
    ld a, $ff
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld [hl], a
ret ;}

; Used for seeking towards Samus
; takes B, D, and E as arguements
; $E9 and $EA form a directional vector (centered at $10, $10)
;
; Caller arguments
;        B   D   E
; Zeta  $02 $20 $00
; Omega $02 $20 $00
; Larva $01 $1E $02
; Baby  $02 $20 $00
; D is the maximum for $E9/$EA
; E is the minimum for $E9/$EA
; B is the movement step in the table (acceleration, basically)
;
; Caller functions should validate the movement afterwards to make sure it doesn't clip into anything.
enemy_seekSamus: ;{ 03:6B44
    ; Load Samus/Enemy positions to adjusted temp variables
    ld hl, seekSamusTemp.samusX
    ld a, [samus_onscreenXPos]
    add $10
    ld [hl-], a
    ld a, [samus_onscreenYPos]
    add $10
    ld [hl-], a
    ldh a, [hEnemyXPos]
    add $10
    ld [hl-], a
    ldh a, [hEnemyYPos]
    add $10
    ld [hl], a
    
    ; Compare Y positions to modify Y component of vector
    ld a, [seekSamusTemp.samusY]
    sub [hl] ; HL = seekSamusTemp.enemyY
    jr z, .endIf_A
        jr c, .else_B
            ; Samus below
            ldh a, [$e9]
            cp d ; Clamp vector Y to max value
            jr z, .endIf_A
                add b
                ldh [$e9], a
                jr .endIf_A
        .else_B:
            ; Samus above
            ldh a, [$e9]
            cp e ; Clamp vector Y to min value
            jr z, .endIf_A
                sub b
                ldh [$e9], a
    .endIf_A:

    ; Compare X positions to modify X component of vector
    inc l
    ld a, [seekSamusTemp.samusX]
    sub [hl] ; HL = seekSamusTemp.enemyX
    jr z, .endIf_C
        jr c, .else_D
            ; Samus right
            ldh a, [hEnemyState]
            cp d ; Clamp vector x to max value
            jr z, .endIf_C
                add b
                ldh [hEnemyState], a
                jr .endIf_C
        .else_D:
            ; Samus left
            ldh a, [hEnemyState]
            cp e ; Clamp vector x to min value
            jr z, .endIf_C
                sub b
                ldh [hEnemyState], a
    .endIf_C:

    ; Adjust y position
    ldh a, [$e9]
    ld e, a
    ld d, $00
    ld hl, .speedTable
    add hl, de
    ld a, [hl]
    ld hl, hEnemyYPos
    add [hl]
    ld [hl], a
    ; Adjust x position
    ldh a, [hEnemyState]
    ld e, a
    ld d, $00
    ld hl, .speedTable
    add hl, de
    ld a, [hl]
    ld hl, hEnemyXPos
    add [hl]
    ld [hl], a
ret ;}

.speedTable: ; 03:6BB1
    db $FB, $FB, $FC, $FC, $FD, $FE, $FD, $FD, $FD, $FF, $FE, $FE, $FE, $FF, $FF, $00
    db $00, $00, $01, $01, $02, $02, $02, $01, $03, $03, $03, $02, $03, $04, $04, $05
    db $05

; Adjust enemy positions (which are in camera-space) due to scrolling
scrollEnemies: ;{ 03:6BD2
    ; Compare current scroll y to the scroll y from one frame ago
    ld hl, scrollHistory_A.y1
    ld de, scrollY
    ld a, [de]
    sub [hl]
    ld b, a ; B now has delta_y
    ; Compare current scroll x to the scroll x from one frame ago
    inc l
    inc e
    ld a, [de]
    sub [hl]
    ld c, a ; C now has delta_x
    ; Return both scroll distance is zero
    or b
        ret z
    ; Exit if no enemies
    ld a, [numEnemies]
    and a
        ret z
    ; Save number of enemies to process
    ld [scrollEnemies_numEnemiesLeft], a

    ; Iterate through enemy slots to find the first enemy
    ld hl, enemyDataSlots - $20 ;$c5e0
    ld de, $0020
.findNextEnemy: ; Jump back here from the end to find next
    .findLoop:
        add hl, de
        ld a, [hl]
        inc a ; Continue until a non-$FF status is found
    jr z, .findLoop

    push hl
        call scrollEnemies_loadToHram ; Load enemy positions to HRAM
        ld hl, hEnemyYPos
        ; Check if we moved up or down
        bit 7, b
        jr z, .else_A
            ; We moved up, so move the enemy down in camera-space
            ld a, b
            cpl ; Negate the negative number to get a positive number
            inc a
            add [hl] ; Thus adding a positive number moves it down
            ld [hl+], a
            ; If value carries and the enemy is offscreen, move it down a screen
            jr nc, .endIf_A
                ldh a, [hEnemyStatus]
                cp $01
                jr nz, .endIf_A
                    ldh a, [hEnemyYScreen]
                    inc a
                    ldh [hEnemyYScreen], a
                    jr .endIf_A
        .else_A:
            ; We moved down, so move the enemy up in camera-space
            ld a, [hl]
            sub b
            ld [hl+], a
            ; If value carries and the enemy is offscreen, move it up a screen
            jr nc, .endIf_A
                ldh a, [hEnemyStatus]
                cp $01
                jr nz, .endIf_A
                    ldh a, [hEnemyYScreen]
                    dec a
                    ldh [hEnemyYScreen], a
        .endIf_A:
    
        ; Check if we moved left or right
        bit 7, c
        jr z, .else_B
            ; We moved left, so move the enemy right in camera-space
            ld a, c
            cpl ; Negate the negative number to get a positive number
            inc a
            add [hl] ; Thus adding a positive number moves it right
            ld [hl], a
            ; If value carries and the enemy is offscreen, move it right a screen
            jr nc, .endIf_B
                ldh a, [hEnemyStatus]
                cp $01
                jr nz, .endIf_B
                    ld hl, hEnemyXScreen
                    inc [hl]
                    jr .endIf_B
        .else_B:
            ; We moved right, so move the enemy left in camera-space
            ld a, [hl]
            sub c
            ld [hl], a
            ; If value carries and the enemy is offscreen, move it left a screen
            jr nc, .endIf_B
                ldh a, [hEnemyStatus]
                cp $01
                jr nz, .endIf_B
                    ld hl, hEnemyXScreen
                    dec [hl]
        .endIf_B:
    
        call scrollEnemies_saveToWram ; Save enemy positions to WRAM
    pop hl
    ; Check if there's another enemy to process
    ld a, [scrollEnemies_numEnemiesLeft]
    dec a
    ld [scrollEnemies_numEnemiesLeft], a
        ret z
jr .findNextEnemy ;}

; Helper function to the above
scrollEnemies_loadToHram: ;{ 03:6C58
    ; Save base address to temp
    ld a, l
    ld [enemy_pWramLow], a
    ld a, h
    ld [enemy_pWramHigh], a
    ; Load status and pixel position
    ld a, [hl+]
    ldh [hEnemyStatus], a
    ld a, [hl+]
    ldh [hEnemyYPos], a
    ld a, [hl]
    ldh [hEnemyXPos], a
    ; Load screen position
    ld a, l
    add $0d
    ld l, a
    ld a, [hl+]
    ldh [hEnemyYScreen], a
    ld a, [hl]
    ldh [hEnemyXScreen], a
ret ;}

; Helper function as well
scrollEnemies_saveToWram: ;{ 03:6C74
    ; Save base address to temp
    ld a, [enemy_pWramLow]
    ld l, a
    ld a, [enemy_pWramHigh]
    ld h, a
    ; Don't bother saving status
    inc l
    ; Save pixel position
    ldh a, [hEnemyYPos]
    ld [hl+], a
    ldh a, [hEnemyXPos]
    ld [hl], a
    ; Save screen position
    ld a, l
    add $0d
    ld l, a
    ldh a, [hEnemyYScreen]
    ld [hl+], a
    ldh a, [hEnemyXScreen]
    ld [hl], a
ret ;}

;------------------------------------------------------------------------------
; Start of queen code

; Neck swoop patterns
queen_neckPatternPointers: ; 03:6C8E - Indexed by queen_neckPattern
    dw table_6C9C ; 0 - Down 1 (curving up)
    dw table_6CB2 ; 1 - Up 1
    dw table_6D00 ; 2 - Down 2 (curving down)
    dw table_6CC8 ; 3 - Up 2
    dw table_6D1E ; 4 - Up, steep (being spat out)
    dw table_6D27 ; 5 - Down, steep, clips through floor (used during death)
    dw table_6CE7 ; 6 - Straight ahead (slight U shape)

table_6C9C: ; 03:6C9C - 0
    db $81, $33, $33, $32, $32, $32, $32, $33, $23, $23, $24, $23, $23, $23, $24, $13
    db $13, $13, $13, $13, $00, $80
table_6CB2: ; 03:6CB2 - 1
    db $81, $E3, $E3, $E3, $E3, $E3, $E2, $E2, $E2, $E2, $E2, $E2, $D2, $D2, $D2, $D2
    db $D2, $D2, $00, $00, $00, $80
table_6CC8: ; 03:6CC8 - 3
    db $81, $01, $01, $01, $01, $F1, $01, $F1, $F1, $F1, $F1, $F1, $F1, $F2, $F2, $E2
    db $E2, $E2, $E2, $E2, $E2, $E2, $D2, $D2, $D2, $D2, $D2, $00, $00, $00, $80
table_6CE7: ; 03:6CE7 - 6
    db $81, $01, $02, $12, $02, $12, $12, $12, $12, $13, $13, $13, $F3, $03, $03, $F3
    db $03, $F3, $F3, $F3, $00, $00, $00, $00, $80
table_6D00: ; 03:6D00 - 2
    db $81, $01, $01, $01, $01, $01, $01, $02, $02, $12, $02, $12, $02, $12, $12, $12
    db $12, $12, $22, $22, $22, $23, $23, $33, $33, $33, $00, $00, $00, $80
table_6D1E: ; 03:6D1E - 4
    db $81, $93, $93, $93, $D3, $00, $00, $00, $80
table_6D27: ; 03:6D27 - 5
    db $81, $10, $20, $20, $20, $20, $20, $21, $21, $20, $20, $20, $20, $20, $20, $21
    db $21, $20, $20, $20, $20, $20, $21, $21, $21, $20, $20, $20, $20, $20, $21, $21
    db $21, $00, $80

; Initialize Queen AI
queen_initialize: ; 03:6D4A
    ld hl, spriteC300
    xor a
    ld b, a

    jr_003_6d4f:
        ld [hl+], a
        dec b
    jr nz, jr_003_6d4f

    ld a, $67
    ld [queen_bodyY], a
    ld a, $37
    ld [queen_bodyHeight], a
    ld a, $44
    ld [rSTAT], a
    ld a, $5c
    ld [queen_bodyXScroll], a
    ld a, [scrollX]
    ld [queen_cameraX], a
    ld a, $03
    ld [rWX], a
    ld [queen_headX], a
    ld a, [scrollY]
    ld [queen_cameraY], a
    ld a, $70
    ld [rWY], a
    ld [queen_headY], a
    ld hl, queen_interruptList
    ld [hl], $ff
    ld a, l
    ld [queen_pInterruptListLow], a
    ld a, h
    ld [queen_pInterruptListHigh], a
    ld a, $09
    ld [$c3b7], a
    ld [$c3b6], a
    ld hl, spriteC300
    ld a, l
    ld [$c3b8], a
    ld a, h
    ld [$c3b9], a
    ; Initialize wall sprites
    ld hl, $c338
    ld b, $0c
    ld a, $78
    jr_003_6daa:
        ld [hl+], a
        ld [hl], $a2
        inc l
        ld [hl], $b0
        inc l
        ld [hl], $00
        inc l
        add $08
        dec b
    jr nz, jr_003_6daa

    call queen_adjustWallSpriteToHead
    ld hl, table_7484
    ld a, l
    ld [queen_pNextStateLow], a
    ld a, h
    ld [queen_pNextStateHigh], a
    ld a, $17 ; Init fight pt 1 (wait to scream)
    ld [queen_state], a
    ld hl, $c600
    ld bc, $01a0

    jr_003_6dd2:
        xor a
        ld [hl+], a
        dec bc
        ld a, b
        or c
    jr nz, jr_003_6dd2

    ld a, $96 ; Set initial health
    ld [queen_health], a
    call Call_003_6f07
    ld hl, $c603
    ld [hl], $f3
    ld l, $23
    ld [hl], $f5
    ld l, $43
    ld [hl], $f1
    ld l, $63
    ld [hl], $f2
    ld hl, $c683
    ld de, $0020
    ld b, $06
    ld a, $f0

    jr_003_6dfc:
        ld [hl], a
        add hl, de
        dec b
    jr nz, jr_003_6dfc

    call Call_003_6e12
    ld a, $01
    ld [queen_headFrameNext], a
    ld [queen_headFrame], a
    ; Set initial delay
    ld a, $8c
    ld [queen_delayTimer], a
ret


Call_003_6e12:
    ld hl, $c680
    ld b, $06
Call_003_6e17:
    ld de, $0020
    ld a, $ff
    jr_003_6e1c:
        ld [hl], a
        add hl, de
        dec b
    jr nz, jr_003_6e1c
ret

; Adjust the wall sprites pertaining to the head to match y position
queen_adjustWallSpriteToHead: ; 03:6E22
    ld hl, $c354
    ld b, $05
    ld a, [queen_headY]
    add $10

    .loop:
        ld [hl+], a
        inc l
        inc l
        inc l
        add $08
        dec b
    jr nz, .loop
ret

queenHandler: ; 03:6E36
    ; Limit actions if Samus is dying
    ld a, [deathFlag]
    and a
    jr z, .endIf_A
        xor a
        ld [queen_footFrame], a
        ld [queen_headFrameNext], a
        ld [$c3e0], a
        call Call_003_7140
        ret
    .endIf_A:

    ; Change palette of neck sprites when hurt
    ld a, [frameCounter]
    and $03
    jr nz, .endIf_B
        ld a, [queen_bodyPalette]
        and a
        jr z, .endIf_B
            xor $90
            ld [queen_bodyPalette], a
            ld b, $0c
            ld hl, $c308
        
            .loop:
                inc l
                inc l
                inc l
                ld a, $10
                xor [hl]
                ld [hl+], a
                dec b
            jr nz, .loop
    .endIf_B:

    ; Set aggression flags?
    ld a, [queen_health]
    and a
    jr z, .endIf_C
        cp $64
        jr nc, .endIf_C
            ld b, a
            ld a, $01
            ld [$c3f1], a
            ld a, b
            cp $32
            jr nc, .endIf_C
                ld a, $01
                ld [$c3ef], a
    .endIf_C:

    call queen_handleState
    call queen_walk
    call Call_003_72b8 ; Neck related?
    call Call_003_7230
    call Call_003_716e
    call Call_003_7190
    call Call_003_71cf
    call Call_003_6f07 ; Set actor positions (for collision detection?)
    call queen_adjustWallSpriteToHead
    call Call_003_7140 ; Copy sprites from C600 area to OAM buffer
    call Call_003_6ea7
ret


Call_003_6ea7:
    ld a, [$c3f0]
    and a
    jr z, jr_003_6eba
        dec a
        ld [$c3f0], a
        jr nz, jr_003_6eba
            xor a
            ld [queen_bodyPalette], a
            call Call_003_7812
    jr_003_6eba:

    ld a, [$d05d]
    ld b, a
    ld a, $ff
    ld [$d05d], a
    ld a, b
    cp $ff
        ret z
    cp $08
        ret nz
    ld a, [$d05f]
    cp $c6
        ret nz
    ld h, a
    ld a, [$d05e]
    cp $20
        jr nz, jr_003_6efe
    ld l, $23
    ld a, [hl]
    cp $f6
        ret z
jr_003_6ede:
    call Call_003_7436
    ld a, $08
    ld [$c3f0], a
    ld a, [queen_bodyPalette]
    and a
    ret nz

    ld a, $93
    ld [queen_bodyPalette], a
    ld a, [$c3ef]
    and a
    ld a, $09
    jr z, jr_003_6efa
        ld a, $0a
    jr_003_6efa:

    ld [sfxRequest_noise], a
    ret


jr_003_6efe:
    cp $40
        jr z, jr_003_6ede
    cp $60
        jr z, jr_003_6ede
    ret

; Set actor positions
Call_003_6f07:
    ; Queen body 
    ld hl, $c601
    ld a, [queen_bodyY]
    add $18
    ld [hl+], a
    ld a, [queen_bodyXScroll]
    cpl
    inc a
    add $30
    ld [hl], a
    ; Queen head left half
    ld l, $41
    ld a, [queen_headY]
    add $10
    ld [hl+], a
    ld a, [queen_headX]
    ld [hl], a
    ; Queen head right half
    ld l, $61
    ld a, [queen_headY]
    add $10
    ld [hl+], a
    ld a, [queen_headX]
    add $20
    ld [hl], a

    ld l, $23
    ld b, $12
    ld c, $0e
    ld a, [hl-]
    cp $f7
    jr nz, jr_003_6f41
        ld b, $15
        ld c, $12
    jr_003_6f41:

    ld a, [queen_headX]
    add b
    ld [hl-], a
    ld a, [queen_headY]
    add c
    ld [hl], a
    call Call_003_6e12
    ld a, [queen_health]
    and a
        ret z
    ld a, [$c3d1]
    and a
    jr nz, jr_003_6f8d
        ld a, [$c3e3]
        and a
            ret nz
        ld a, [$c3b8]
        cp $00
            ret z
        inc a
        ld l, a
        ld a, [$c3b9]
        ld h, a
        ld de, $c683
        ld a, $f0
        ld [de], a
        dec e
    
        jr_003_6f71:
            ld a, [hl-]
            ld [de], a
            dec e
            ld a, [hl]
            ld [de], a
            dec e
            xor a
            ld [de], a
            push de
            ld de, $fff9
            add hl, de
            pop de
            push hl
            ld hl, $0022
            add hl, de
            ld e, l
            ld d, h
            pop hl
            ld a, l
            cp $01
        jr nz, jr_003_6f71
        ret
    jr_003_6f8d:
        ld de, $c308
        ld hl, $c680
        ld [hl], $00
        inc l
        ld a, [de]
        add $10
        ld [hl+], a
        inc e
        ld a, [de]
        add $10
        ld [hl+], a
        ld [hl], $82
        ret

; Queen head tilemaps
queen_headFrameA: ; 03:6FA2
    db $BB, $B1, $B2, $B3, $B4, $FF
    db $C0, $C1, $C2, $C3, $C4, $FF
    db $D0, $D1, $D2, $D3, $D4, $D5
    db $FF, $FF, $E2, $E3, $E4, $E5
    db $FF, $FF, $FF, $FF, $FF, $FF
    db $FF, $FF, $FF, $FF, $FF, $FF
queen_headFrameB: ; 03:6FC6
    db $BB, $B1, $F5, $B8, $B9, $BA
    db $C0, $C1, $C7, $C8, $C9, $CA
    db $D0, $E6, $D7, $D8, $FF, $FF
    db $FF, $F6, $E7, $E8, $FF, $FF
    db $FF, $FF, $F7, $F8, $FF, $FF
    db $FF, $FF, $FF, $FF, $FF, $FF
queen_headFrameC: ; 03:6FEA
    db $FF, $BC, $BD, $BE, $FF, $FF
    db $FF, $CB, $CC, $CD, $FF, $FF
    db $DA, $DB, $DC, $DD, $FF, $FF
    db $EA, $EB, $EC, $ED, $DE, $FF
    db $FA, $FB, $FC, $FD, $EE, $D9
    db $FF, $FF, $FF, $FF, $FF, $FF

queen_drawHead:
    .resume_A: ; 03:700E
        ld a, [queen_headDest]
        ld l, a
        ld a, [queen_headSrcHigh]
        ld d, a
        ld a, [queen_headSrcLow]
        ld e, a
        ld h, $9c
        jr .resume_B
.entry: ; 03:701E - Entry point
    ld a, [queen_headFrameNext]
    and a
        ret z
    cp $ff
        jr z, .resume_A

    ld de, queen_headFrameA
    cp $01
    jr z, .endIf
        ld de, queen_headFrameB
        cp $02
        jr z, .endIf
            ld de, queen_headFrameC
    .endIf:

    ld hl, $9c00
  .resume_B:
    ld c, $03 ; Draw only 3 rows per frame (split update into two frames)

    .drawLoop:
        ld b, $06
        .rowLoop:
            ld a, [de]
            ld [hl+], a
            inc de
            dec b
        jr nz, .rowLoop
    
        ld a, $1a
        add l
        ld l, a
        dec c
    jr nz, .drawLoop

    ld a, [queen_headFrameNext]
    cp $ff
    jr nz, .else
        ; Finished rendering
        xor a
        ld [queen_headFrameNext], a
        ret
    .else:
        ; Continue rendering next frame
        ld a, l
        ld [queen_headDest], a
        ld a, d
        ld [queen_headSrcHigh], a
        ld a, e
        ld [queen_headSrcLow], a
        ld a, $ff
        ld [queen_headFrameNext], a
        ret
; end proc

; 03:706A - Rendering the Queen's feet
queen_drawFeet:
    ; Try drawing the head if the next frame is zero
    ld a, [queen_footFrame]
    and a
        jr z, queen_drawHead.entry
    ; Save frame to B
    ld b, a
    ; Try drawing the head if the animation delay is non-zero
    ld a, [queen_footAnimCounter]
    and a
    jr z, .endIf_A
        dec a
        ld [queen_footAnimCounter], a
            jr queen_drawHead.entry
    .endIf_A:

    ; Reload the animation counter
    ld a, $01
    ld [queen_footAnimCounter], a
    ; Select the front or back feet depending on the LSB of the animation frame
    ld a, b
    bit 7, a ; Bit 7 == 0 -> do the front foot, else do the rear foot
    ld hl, queen_frontFootPointers
    ld de, queen_frontFootOffsets
    ld b, $0c ; Number of tiles to update
    jr z, .endIf_B
        ld hl, queen_rearFootPointers
        ld de, queen_rearFootOffsets
        ld b, $10 ; Number of tiles to update
    .endIf_B:
    
    ; Get the foot tilemap/tile-offset pointers
    push de
        and $7f ; Mask out the bit determining which foot to render
        dec a   ; Adjusting because the value zero earlier meant "skip rendering"
        sla a
        ld e, a
        ld d, $00
        add hl, de
        ld e, [hl]
        inc hl
        ld d, [hl]
    pop hl
    ; HL now points to the offset table
    ; DE now points to the tilemap

    .vramUpdateLoop:
        push bc ; push the loop counter (b) on to the stack
            ; VRAM Offset: BC = $9A00 + [HL]
            ld b, $9a
            ld c, [hl]
            ; DE points to the current tile number to render
            ld a, [de]
            ld [bc], a ; Write to VRAM
            inc hl
            inc de
        pop bc ; pop the loop counter from the stack
        dec b
    jr nz, .vramUpdateLoop

    ; Don't increment the frame counter if we rendered the front foot
    ld a, [queen_footFrame]
    bit 7, a
    jr z, .endIf_C
        inc a
    .endIf_C:
    
    xor $80 ; Swap which foot to render next frame
    and $83 ; Mask frame numbers greater than 3
    ; inc if zero so we don't stop animating the feet
    jr nz, .endIf_D
        inc a
    .endIf_D:
    ld [queen_footFrame], a
ret

; Pointers, tile numbers, and tilemap offsets for the rear and front feet.
queen_rearFootPointers:
    dw queen_rearFoot1, queen_rearFoot2, queen_rearFoot3
queen_frontFootPointers:
    dw queen_frontFoot1, queen_frontFoot2, queen_frontFoot3
    
; 03:70D0
queen_rearFoot1:
    db     $21,$22,$23,$24
    db $30,$31,$32,$33
    db $40,$41,$42,    $44
    db $50,$51,$52,$53
queen_rearFoot2:
    db     $2c,$2d,$2e,$2f
    db $3b,$3c,$3d,$3e
    db $4b,$4c,$4d,    $4f
    db $7f,$f2,$ef,$df
queen_rearFoot3:
    db     $2c,$2d,$2e,$2f 
    db $3b,$3c,$3d,$3e
    db $4b,$4c,$4d,    $4f
    db $10,$11,$12,$df

; 03:7100
queen_frontFoot1:
    db $28,$29,$2a
    db $38,$39,$3a
    db $48,$49,$4a
    db $fe,$f9,$f4
queen_frontFoot2:
    db $1b,$1c,$1d
    db $03,$04,$05
    db $0e,$0f,$1f
    db $ff,$ff,$ff
queen_frontFoot3:
    db $1b,$1c,$1d
    db $03,$04,$05
    db $0e,$0f,$1f
    db $00,$01,$02
    
; 03:7124
queen_rearFootOffsets:
    db     $01,$02,$03,$04
    db $20,$21,$22,$23
    db $40,$41,$42,    $44
    db $60,$61,$62,$63
queen_frontFootOffsets:
    db $08,$09,$0a 
    db $28,$29,$2a 
    db $48,$49,$4a
    db $68,$69,$6a

; No more code about the Queen's feet, please.

; Copy sprites to OAM buffer
Call_003_7140:
    ; Copy the 6 segments of the neck (or the spit projectiles)
    ld hl, $c308
    ld a, [hOamBufferIndex]
    ld e, a
    ld d, HIGH(wram_oamBuffer)
    ld c, $06
    jr_003_714b:
        ld a, [$c3b8]
        add $08
        cp l
            jr z, jr_003_715e
        ld b, $08
        jr_003_7155:
            ld a, [hl+]
            ld [de], a
            inc de
            dec b
        jr nz, jr_003_7155
    
        dec c
    jr nz, jr_003_714b
    
    jr_003_715e:

    ; Copy the wall segments
    ld hl, $c338
    ld b, $30
    jr_003_7163:
        ld a, [hl+]
        ld [de], a
        inc de
        dec b
    jr nz, jr_003_7163

    ld a, e
    ld [hOamBufferIndex], a
ret


Call_003_716e:
    ld a, [queen_cameraY]
    ld b, a
    ld a, [scrollY]
    cp $f8
    jr c, .endIf
        xor a
    .endIf:
    ld [queen_cameraY], a
    sub b
    ld [queen_cameraDeltaY], a
    
    ld a, [queen_cameraX]
    ld b, a
    ld a, [scrollX]
    ld [queen_cameraX], a
    sub b
    ld [queen_cameraDeltaX], a
ret


Call_003_7190:
    ld a, [queen_cameraDeltaX]
    ld b, a
    ld a, [queen_bodyXScroll]
    add b
    ld [queen_bodyXScroll], a
    ld a, [queen_headX]
    sub b
    ld [queen_headX], a
    ld a, [queen_cameraDeltaY]
    ld b, a
    ld a, [queen_headY]
    sub b
    ld [queen_headY], a
    ld a, [scrollY]
    cp $f8
    jr c, jr_003_71b5
        xor a
    jr_003_71b5:

    ld c, a
    ld a, $67
    sub c
    jr c, jr_003_71c4
        ld [queen_bodyY], a
        ld a, $37
        ld [queen_bodyHeight], a
        ret
    jr_003_71c4:
        ld d, $37
        add d
        ld [queen_bodyHeight], a
        xor a
        ld [queen_bodyY], a
        ret


Call_003_71cf:
    ld a, [$c3d1]
    ld d, $05
    and a
    jr z, jr_003_71d9
        ld d, $01
    jr_003_71d9:

    ld a, [queen_cameraDeltaX]
    ld b, a
    ld a, [queen_cameraDeltaY]
    ld c, a
    ld a, [$c3b8]
    cp $00
    jr z, jr_003_7215
        add d
        ld l, a
        ld a, [$c3b9]
        ld h, a
    
        jr_003_71ee:
            ld a, [hl]
            sub b
            ld [hl-], a
            ld a, [hl]
            sub c
            ld [hl-], a
            dec l
            dec l
            ld a, $05
            cp l
        jr nz, jr_003_71ee
    
        ld hl, $c741
        ld d, $03
    
        jr_003_7200:
            call Call_003_7229
            ld a, l
            add $1e
            ld l, a
            dec d
        jr nz, jr_003_7200
    
        ld hl, $c3e6
        ld d, $03
    
        jr_003_720f:
            call Call_003_7229
            dec d
        jr nz, jr_003_720f
    jr_003_7215:

    ld hl, $c338
    ld d, $0c
    jr_003_721a:
        ld a, [hl]
        sub c
        ld [hl+], a
        ld a, [hl]
        sub b
        ld [hl+], a
        inc l
        inc l
        dec d
    jr nz, jr_003_721a

    call queen_adjustWallSpriteToHead
ret


Call_003_7229:
    ld a, [hl]
    sub c
    ld [hl+], a
    ld a, [hl]
    sub b
    ld [hl+], a
ret


Call_003_7230:
    ld a, [$c3b8]
    ld l, a
    ld a, [$c3b9]
    ld h, a
    ld a, [$c3ba]
    and a
        ret z
    cp $01
    jr nz, jr_003_7291

    ld a, [$c3b6]
    cp $08
    jr nc, jr_003_724e

    ld a, [$c3b7]
    cp $0c
    ret c

jr_003_724e:
    xor a
    ld [$c3b6], a
    ld [$c3b7], a
    ld a, $30
    cp l
    ret z

    ld de, $0008
    add hl, de
    push hl
    ld a, [queen_headFrame]
    ld b, $15
    cp $03
    jr nz, jr_003_7269
        ld b, $27
    jr_003_7269:

    ld a, [queen_headY]
    add b
    ld [hl+], a
    ld b, a
    ld a, [queen_headX]
    sub $00
    ld [hl+], a
    ld c, a
    ld [hl], $b5
    inc l
    ld [hl], $80
    inc l
    ld a, b
    add $08
    ld [hl+], a
    ld [hl], c
    inc l
    ld [hl], $c5
    inc l
    ld [hl], $80
    pop hl

Jump_003_7288:
jr_003_7288:
    ld a, l
    ld [$c3b8], a
    ld a, h
    ld [$c3b9], a
    ret


jr_003_7291:
    ld a, [$c3b6]
    cp $08
    jr nc, jr_003_729e

    ld a, [$c3b7]
    cp $0c
    ret c

jr_003_729e:
    ld a, $07
    ld [$c3b6], a
    ld [$c3b7], a
    ld [hl], $ff
    ld de, $0004
    add hl, de
    ld [hl], $ff
    ld de, $fff4 ; Unsure if this is hEnemyXScreen
    add hl, de
    ld a, $00
    cp l
    ret z

    jr jr_003_7288

Call_003_72b8:
    ld a, [queen_neckControl]
    and a ; Case 0 - Do nothing
        ret z
    cp $03 ; Case 3 - Follow body walking
        jp z, Jump_003_742a
    ld b, a
    ; Load pointer
    ld a, [queen_pNeckPatternLow]
    ld l, a
    ld a, [queen_pNeckPatternHigh]
    ld h, a
    
    ld a, b
    cp $01
        jp nz, Jump_003_73b1

    ld a, [queen_eatingState]
    cp $10 ; Check if paralyzed
    jr nz, jr_003_7314
        ld hl, $c623
        ld a, [hl]
        cp $f6
        jr z, jr_003_72ff
            ld a, [queen_stunTimer]
            and a
            jr z, jr_003_72f5
                dec a
                ld [queen_stunTimer], a
                cp $58
                    ret nz
                xor a
                ld [queen_bodyPalette], a
                call Call_003_7812
                ret
            jr_003_72f5:
                xor a
                ld [queen_eatingState], a
                ld hl, $c623
                ld [hl], $f6
                ret
        jr_003_72ff:
            ld a, $60
            ld [queen_stunTimer], a
            ld a, $93
            ld [queen_bodyPalette], a
            ld a, $0a
            ld [sfxRequest_noise], a
            ld hl, $c623
            ld [hl], $f7
            ret
    jr_003_7314:

    cp $01
        ret z
    cp $02
    jr nz, jr_003_7328

    xor a
    ld [queen_bodyPalette], a
    call Call_003_7812
    ld a, $0d ; Prep Samus in mouth
    ld [queen_state], a
    ret


jr_003_7328:
    ld a, [hl]
    cp $80
    jr z, jr_003_73a2

    ld a, [queen_headY]
    ld c, a
    ld a, [hl]
    and $f0
    bit 7, a
    jr z, jr_003_733a
        or $0f
    jr_003_733a:
    swap a
    add c
    cp $d0
    jr c, jr_003_735c
        ld a, [$c3d1]
        and a
        jr nz, jr_003_7355
            ld a, $04 ; Prep retraction
            ld [queen_state], a
            xor a
            ld [queen_walkStatus], a
            ld [queen_neckStatus], a
            jr jr_003_7399
        jr_003_7355:
            ld a, $0a ; Spitting Samus out
            ld [queen_state], a
            jr jr_003_7399
    jr_003_735c:

    ld [queen_headY], a
    ld a, [hl]
    and $f0
    swap a
    ld b, a
    bit 3, a
    jr z, jr_003_736e
        or $f0
        cpl
        inc a
        ld b, a
    jr_003_736e:

    ld a, [$c3b7]
    add b
    ld [$c3b7], a
    ld a, [hl]
    and $0f
    ld c, a
    ld a, [queen_headX]
    add c
    ld [queen_headX], a
    ld a, [$c3b6]
    add c
    ld [$c3b6], a
    inc hl
    ld a, [$c3ef]
    and a
    jr z, jr_003_7399

    dec a
    ld [$c3ef], a
    push hl
    call Call_003_7230
    pop hl
    jr jr_003_7328

Jump_003_7399:
jr_003_7399: ; Save neck pattern and exit
    ld a, l
    ld [queen_pNeckPatternLow], a
    ld a, h
    ld [queen_pNeckPatternHigh], a
    ret


jr_003_73a2:
    xor a
    ld [queen_neckControl], a
    ld [$c3ba], a
    ld a, $81
    ld [queen_neckStatus], a
    dec hl
    jr jr_003_7399 ; Save Neck Pattern and Exit

Jump_003_73b1:
    ld a, [frameCounter]
    and $01
    ret z

    ld a, [hl]
    cp $81
    jr z, jr_003_73fc

        ld a, [hl]
        and $f0
        swap a
        bit 3, a
        jr z, jr_003_73cc
            or $f0
            cpl
            inc a
            ld b, a
            jr jr_003_73cf
        jr_003_73cc:
            cpl
            inc a
            ld b, a
        jr_003_73cf:
    
        ld a, [queen_headY]
        add b
        ld [queen_headY], a
        bit 7, b
        jr nz, jr_003_73de
            ld a, b
            cpl
            inc a
            ld b, a
        jr_003_73de:
    
        ld a, [$c3b7]
        add b
        ld [$c3b7], a
        ld a, [hl]
        and $0f
        cpl
        inc a
        ld b, a
        ld a, [queen_headX]
        add b
        ld [queen_headX], a
        ld a, [$c3b6]
        add b
        ld [$c3b6], a
        dec hl
        jr jr_003_7399
    jr_003_73fc:
        xor a
        ld [queen_neckControl], a
        ld [$c3ba], a
        ld a, $82
        ld [queen_neckStatus], a
        xor a
        ld [queen_eatingState], a
        ld hl, $c623
        ld [hl], $f5
        ld hl, spriteC300
        ld a, l
        ld [$c3b8], a
        ld a, h
        ld [$c3b9], a
        ld a, $09
        ld [$c3b6], a
        ld [$c3b7], a
        call Call_003_7466
        jp Jump_003_7399


Jump_003_742a:
    ld a, [queen_walkSpeed]
    ld b, a
    ld a, [queen_headX]
    add b
    ld [queen_headX], a
ret


Call_003_7436:
    ld a, [queen_health]
    and a
        ret z
    dec a ; Hurt for one damage
    ld [queen_health], a
        ret nz
    ; Do this is the hit was fatal
    ld a, $81
    ld [queen_neckStatus], a
    ld a, $11 ; Prep death
    ld [queen_state], a
    xor a
    ld [queen_neckControl], a
    ld [queen_walkControl], a
    ld [queen_footFrame], a
    ld [queen_headFrameNext], a
    call Call_003_6e12
    ld b, $04
    ld hl, $c600
    call Call_003_6e17
    call Call_003_7aa8
ret


Call_003_7466:
    ld a, [queen_pNeckPatternBaseLow]
    ld l, a
    ld a, [queen_pNeckPatternBaseHigh]
    ld h, a
ret


Call_003_746f:
    ld a, [queen_neckPattern]
    sla a
    ld e, a
    ld d, $00
    ld hl, queen_neckPatternPointers
    add hl, de
    ld a, [hl+]
    ld [queen_pNeckPatternBaseLow], a
    ld a, [hl]
    ld [queen_pNeckPatternBaseHigh], a
ret

; Queen state table
table_7484: ; 03:7484
    db $00, $02, $04, $02, $04, $06, $14, $ff
; Walk forward, shove head forward twice, walk back, spit blobs, repeat

queen_handleState: ; 03:748C
    ld a, [queen_state] ; Queen's state!
    rst $28
        dw func_03_7821 ; $00 - 03:7821 - Prep forward walk
        dw func_03_783C ; $01 - 03:783C - Walking forward
        dw func_03_7864 ; $02 - 03:7864 - Prep neck extension
        dw func_03_78EE ; $03 - 03:78EE - Extending neck
        dw func_03_78F7 ; $04 - 03:78F7 - Prep retraction
        dw func_03_7932 ; $05 - 03:7932 - Retracting neck
        dw func_03_793B ; $06 - 03:793B - Prep backwards walking
        dw func_03_7954 ; $07 - 03:7954 - Walking backward
        dw func_03_7970 ; $08 - 03:7970 - Stomach just bombed
        dw func_03_79D0 ; $09 - 03:79D0 - Prep spitting Samus out of stomach
        dw func_03_79E1 ; $0A - 03:79E1 - Spitting Samus out of stomach
        dw func_03_7A1D ; $0B - 03:7A1D - Done spitting Samus out of stomach
        dw func_03_7846 ; $0C - 03:7846 - Init fight pt 3 (choose next state)
        dw func_03_772B ; $0D - 03:772B - Prep Samus in mouth
        dw func_03_776F ; $0E - 03:776F - Samus in mouth (head retracting)
        dw func_03_7785 ; $0F - 03:7785 - Samus in mouth/stomach (head retracted)
        dw func_03_77DD ; $10 - 03:77DD - Spitting Samus out of mouth
        dw func_03_7ABF ; $11 - 03:7ABF - Prep death
        dw func_03_7B05 ; $12 - 03:7B05 - Dying pt 1 (disintegrating)
        dw func_03_7B9D ; $13 - 03:7B9D - Dying pt 2
        dw func_03_7519 ; $14 - 03:7519 - Prepping blob spit
        dw func_03_757B ; $15 - 03:757B - Blobs out
        dw func_03_7BE7 ; $16 - 03:7BE7 - Dying pt 3
        dw func_03_74C4 ; $17 - 03:74C4 - Init fight pt 1 (wait to scream)
        dw func_03_74EA ; $18 - 03:74EA - Init fight pt 2 (wait to start)
        dw enAI_NULL ; $19 - Wrong bank, you silly programmer.

func_03_74C4:
    ld a, [queen_delayTimer]
    and a
    jr z, jr_003_74cf

jr_003_74ca:
    dec a

jr_003_74cb:
    ld [queen_delayTimer], a
    ret


jr_003_74cf:
    ld a, $02
    ld [queen_headFrameNext], a
    ld a, $18 ; Init fight part 2 (wait to start)
    ld [queen_state], a
    ld a, [$c3ef]
    and a
    ld a, $09
    jr z, jr_003_74e3
        ld a, $0a
    jr_003_74e3:
    ld [sfxRequest_noise], a
    ld a, $32
    jr jr_003_74cb

func_03_74EA:
    ld a, [queen_delayTimer]
    and a
        jr nz, jr_003_74ca
    ld a, $01
    ld [queen_headFrameNext], a
    ld a, $0c ; Init fight part 3
    ld [queen_state], a
ret


Call_003_74fb:
    ld de, samus_onscreenYPos
    ld hl, $c3e6
    ld a, [de]
    ld b, a
    ld [hl+], a
    inc de
    ld a, [de]
    ld c, a
    ld [hl+], a
    ld a, $f0
    add b
    ld [hl+], a
    ld a, $f0
    add c
    ld [hl+], a
    ld a, $10
    add b
    ld [hl+], a
    ld a, $10
    add c
    ld [hl], a
    ret

func_03_7519:
    call Call_003_74fb
    ld a, [queen_headY]
    add $20
    ld b, a
    ld a, [queen_headX]
    add $1c
    ld c, a
    ld hl, $c740
    ld d, $20
    call Call_003_756c
    ld l, $60
    ld d, $20
    call Call_003_756c
    ld l, $80
    ld d, $21
    call Call_003_756c
    ld hl, $c308
    ld de, $c740
    ld b, $03
    call Call_003_75fa
    ld a, $0e
    ld [$c3ee], a
    ld a, $02
    ld [queen_headFrameNext], a
    ld a, $20
    ld [queen_delayTimer], a
    ld a, $10
    ld [$c3e5], a
    ld a, $15 ; Blobs out
    ld [queen_state], a
    ld [$c3e3], a
    ld de, $fff8
    add hl, de
    jp Jump_003_7288

; Spawn Queen's spit
Call_003_756c: ; 03:756C
    ; Set status
    ld [hl], $00
    ; Set Y
    inc l
    ld [hl], b
    ; Set X
    inc l
    ld [hl], c
    ; Set sprite type
    inc l
    ld [hl], $f2
    ; Set flip flags
    ld a, l
    add $05
    ld l, a
    ld [hl], d
ret

; Queen state - blobs out
func_03_757B: ; 03:757B
    ld a, [queen_delayTimer]
    and a
    jr z, jr_003_758c
        dec a
        ld [queen_delayTimer], a
        jr nz, jr_003_758c
            ld a, $01
            ld [queen_headFrameNext], a
    jr_003_758c:

    call Call_003_7658
    ld a, [$d05d]
    cp $ff
    jr z, jr_003_75b4

    cp $20
    jr z, jr_003_75b4

    cp $08
    jr z, jr_003_75a2

    cp $10
    jr nz, jr_003_75b4

jr_003_75a2:
    ld a, [$d05f]
    cp $c7
    jr nz, jr_003_75b4

    ld h, a
    ld a, [$d05e]
    cp $40
    jr c, jr_003_75b4

    ld l, a
    ld [hl], $ff

jr_003_75b4:
    ld a, $ff
    ld [$d05d], a
    ld de, $0020
    ld hl, $c740
    ld b, $03

    jr_003_75c1:
        ld a, [hl]
        cp $ff
            jr nz, jr_003_75cc
        add hl, de
        dec b
    jr nz, jr_003_75c1

    jr jr_003_75d0

jr_003_75cc:

    call Call_003_75fa
    ret


jr_003_75d0:
    ld hl, $c740
    ld de, $0020
    ld b, $03

    jr_003_75d8:
        ld [hl], $ff
        add hl, de
        dec b
    jr nz, jr_003_75d8

    ld hl, $c308
    ld de, $0004
    ld b, $0c
    ld a, $ff

    jr_003_75e8:
        ld [hl], a
        add hl, de
        dec b
    jr nz, jr_003_75e8

    call Call_003_7846
    xor a
    ld [$c3e3], a
    ld hl, spriteC300
    jp Jump_003_7288


Call_003_75fa:
    ld hl, $c308
    ld de, $c740
    ld b, $03

jr_003_7602:
    push bc

jr_003_7603:
    push de
    ld a, [de]
    ld bc, $f0f0
    cp $ff
    jr z, jr_003_761a

    inc e
    ld a, [de]
    cp $e0
    jr nc, jr_003_7627

    ld b, a
    inc e
    ld a, [de]
    cp $e0
    jr nc, jr_003_7627

    ld c, a

jr_003_761a:
    call Call_003_762d
    pop de
    pop bc
    ld a, e
    add $20
    ld e, a
    dec b
    jr nz, jr_003_7602

    ret


jr_003_7627:
    pop de
    ld a, $ff
    ld [de], a
    jr jr_003_7603

Call_003_762d:
    ld d, $f1
    ld e, $c0
    call Call_003_764f
    ld a, $f8
    add b
    ld b, a
    ld e, $80
    call Call_003_764f
    ld a, $f8
    add c
    ld c, a
    dec d
    call Call_003_764f
    ld a, $08
    add b
    ld b, a
    ld e, $c0
    call Call_003_764f
ret


Call_003_764f:
    ld [hl], b
    inc l
    ld [hl], c
    inc l
    ld [hl], d
    inc l
    ld [hl], e
    inc l
    ret

; Handle queen's spit
Call_003_7658:
    ld b, $03
    ld hl, $c740

    jr_003_765d:
        push hl
        push bc
        ld a, [hl]
        and a
        jr nz, jr_003_7666
            call Call_003_7701
        jr_003_7666:
        pop bc
        pop hl
        ld de, $0020
        add hl, de
        dec b
    jr nz, jr_003_765d

    ld a, [$c3e5]
    and a
    jr z, jr_003_767a
        dec a
        ld [$c3e5], a
        ret
    jr_003_767a:

    ld a, $03
    ld [$c3e5], a
    ld a, [$c3ee]
    and a
        ret z
    dec a
    ld [$c3ee], a
    call Call_003_74fb
    ld hl, $c748
    ld de, $c3e6
    ld b, $03

    jr_003_7693:
        push hl
        push de
        push bc
        call Call_003_76a6
        pop bc
        pop de
        pop hl
        ld a, l
        add $20
        ld l, a
        inc de
        inc de
        dec b
    jr nz, jr_003_7693
ret


Call_003_76a6:
    ld a, [hl]
    ld [$c3e4], a
    ld a, l
    sub $07
    ld l, a
    ld a, [$c3e4]
    and $0f
    ld c, a
    call Call_003_76d5
    inc de
    inc hl
    ld a, c
    and $0f
    ld b, a
    ld a, [$c3e4]
    and $f0
    swap a
    ld c, a
    call Call_003_76d5
    ld a, c
    and $0f
    swap a
    or b
    ld b, a
    ld a, l
    add $06
    ld l, a
    ld [hl], b
    ret


Call_003_76d5:
    ld a, [de]
    sub [hl]
    ret z

    push af
    cp $06
    jr c, jr_003_76fb

    cp $fa
    jr nc, jr_003_76fb

jr_003_76e1:
    pop af
    ld a, c
    jr nc, jr_003_76f0

    cp $0e
    ret z

    dec a
    and $0f
    jr nz, jr_003_76ee

    dec a

jr_003_76ee:
    ld c, a
    ret


jr_003_76f0:
    cp $02
    ret z

    inc a
    and $0f
    jr nz, jr_003_76ee

    inc a
    jr jr_003_76ee

jr_003_76fb:
    ld a, c
    and a
    jr nz, jr_003_76e1

    pop af
    ret


Call_003_7701:
    ld b, $02
    inc hl
    push hl
        ld a, l
        add $07
        ld l, a
        ld a, [hl]
        ld [$c3e4], a
    pop hl
    push hl
        ld a, [$c3e4]
        jr_003_7712:
            and $0f
            jr z, jr_003_7720
                bit 3, a
                jr nz, jr_003_771e
                    inc [hl]
                    inc [hl]
                    jr jr_003_7720
                jr_003_771e:
                    dec [hl]
                    dec [hl]
            jr_003_7720:
        
            inc hl
            ld a, [$c3e4]
            swap a
            dec b
        jr nz, jr_003_7712
    pop hl
    ret

; Prep Samus in mouth
func_03_772B: ; 03:772B
    ld a, [queen_pNeckPatternLow]
    ld l, a
    ld a, [queen_pNeckPatternHigh]
    ld h, a
    ld a, [hl]
    cp $81
    jp z, Jump_003_7846

    ld a, $02
    ld [$c3ba], a
    ld [queen_neckControl], a
    ld a, [queen_headFrame]
    cp $03
    jr nz, jr_003_7750
        ld a, [queen_headY]
        add $10
        ld [queen_headY], a
    jr_003_7750:

    ld a, $01
    ld [queen_headFrameNext], a
    ld [queen_headFrame], a
    xor a
    ld [queen_neckStatus], a
    ld a, $ff
    ld [$c620], a
    ld a, $f5
    ld [$c623], a
    ld a, $0e ; Samus in mouth (head retracting)
    ld [queen_state], a
    dec hl
    jp Jump_003_7399

func_03_776F:
    ld a, [queen_neckStatus]
    cp $82
        ret nz
    ld a, $03
    ld [queen_eatingState], a
    ld a, $0f ; Samus in mouth/stomach (head retracted)
    ld [queen_state], a
    ld a, $01
    ld [queen_footFrame], a
ret

func_03_7785: ; 03:7785 - State $0F
    ld a, [queen_eatingState]
    cp $04
    jr nz, jr_003_77b8

    ld a, [queen_health]
    sub $0a ; Hurt for 10 damage?
    ld [queen_health], a
    jr c, jr_003_77d5

    ld a, $05
    ld [queen_eatingState], a
    ld a, $02
    ld [queen_headFrameNext], a
    ld [queen_headFrame], a
    ld a, $10 ; Spitting Samus out of mouth
    ld [queen_state], a
    ld a, $3e
    ld [queen_stunTimer], a
    ld a, $93
    ld [queen_bodyPalette], a
    ld a, $0a
    ld [sfxRequest_noise], a
    ret


jr_003_77b8:
    cp $06
    jr nz, jr_003_77bd

    ret


jr_003_77bd:
    cp $07
    ret nz

    ld a, $08

jr_003_77c2:
    ld [queen_eatingState], a
    ld a, $08 ; Queen just bombed
    ld [queen_state], a
    ld a, $93
    ld [queen_bodyPalette], a
    ld a, $0a
    ld [sfxRequest_noise], a
    ret


jr_003_77d5:
    xor a
    ld [queen_health], a
    ld a, $20
    jr jr_003_77c2

func_03_77DD:
    ld a, [queen_stunTimer]
    and a
    jr z, jr_003_77fd

    dec a
    ld [queen_stunTimer], a
    cp $2e
    jr nz, jr_003_77f2

    xor a
    ld [queen_bodyPalette], a
    call Call_003_7812

jr_003_77f2:
    ld a, [queen_footFrame]
    cp $02
        ret nz
    xor a
    ld [queen_footFrame], a
    ret


jr_003_77fd:
    ld [queen_eatingState], a
    ld a, $01
    ld [queen_headFrameNext], a
    ld [queen_headFrame], a
    ; Pointless state assignment given the jump right there
    ld a, $06 ; Prep walking backwards
    ld [queen_state], a
    ld hl, table_7484 + 6 ;$748a
    jr jr_003_7856 ; Set state to queen_stateTable[6]

; Set sprite attributes for neck
Call_003_7812:
    ld b, $0c
    ld hl, spriteC300 + 8 ;$c308
    .loop:
        inc l
        inc l
        inc l
        ld a, OAMF_PRI ;$80
        ld [hl+], a
        dec b
    jr nz, .loop
ret

func_03_7821:
    xor a
    ld [queen_walkCounter], a
    ld [$c3ba], a
    inc a
    ld [queen_walkControl], a
    ld a, $03
    ld [queen_neckControl], a
    ld a, $02
    ld [queen_footFrame], a
    ld a, $01 ; Walking forward
    ld [queen_state], a
ret

func_03_783C:
    ld a, [queen_walkStatus]
    cp $81
        ret nz
    xor a
    ld [queen_footFrame], a

func_03_7846:
Call_003_7846:
Jump_003_7846:
    ld a, [queen_pNextStateLow]
    ld l, a
    ld a, [queen_pNextStateHigh]
    ld h, a

jr_003_784e:
    ld a, [hl+]
    cp $ff
    jr z, jr_003_785f
        ld [queen_state], a
      jr_003_7856: ; Jump to set next state pointer directly
        ld a, l
        ld [queen_pNextStateLow], a
        ld a, h
        ld [queen_pNextStateHigh], a
        ret
    jr_003_785f:
        ld hl, table_7484
        jr jr_003_784e
; end proc?

func_03_7864:
    ld hl, $c620
    ld [hl], $00
    ld a, $01
    ld [queen_neckControl], a
    ld [$c3ba], a
    ld a, $03 ; Extending neck
    ld [queen_state], a
    ld a, [$c3be]
    xor $01
    ld [$c3be], a
    ld a, [$c3f1]
    and a
    jr nz, jr_003_78ac
        ld a, [$c3be]
        and a
        jr z, jr_003_78ac
            ld a, [queen_headY]
            ld b, $02 ; downwards neck pattern
            cp $46
            jr c, jr_003_78a5
                ld b, $03 ; Upwards neck pattern
                ld a, [queen_headY]
                add $f0
                ld [queen_headY], a
                ld a, $03
                ld [queen_headFrameNext], a
                ld [queen_headFrame], a
            jr_003_78a5:
            
            ld a, b
            ld [queen_neckPattern], a
            jp Jump_003_78e4
    jr_003_78ac:
        ld a, [queen_headY]
        ld b, $00 ; downwards neck pattern
        cp $29
        jr c, jr_003_78c5
            ld b, $06 ; Forwards neck pattern
            cp $4c
            jr c, jr_003_78c5
                ld b, $01 ; Upwards neck pattern
                ld a, [queen_headY]
                add $f0
                ld [queen_headY], a
        jr_003_78c5:
    
        ld a, b
        ld [queen_neckPattern], a
        
        ; Randomly select head pose
        ld b, $03
        cp $01
        jr z, jr_003_78dd
            ld b, $02
            ld a, [rDIV]
            and $03
            jr z, jr_003_78e4
                ld hl, $c623
                ld [hl], $f6
        jr_003_78dd:
    
        ld a, b
        ld [queen_headFrameNext], a
        ld [queen_headFrame], a
    Jump_003_78e4:
    jr_003_78e4:

    ; Load neck pattern pointer
    call Call_003_746f
    ; Skip first entry in the neck pattern table
    call Call_003_7466 ; Load
    inc hl 
    jp Jump_003_7399 ; Store
; end proc

; Extending neck
func_03_78EE: ; 03:78EE
    ; Wait until status is $81
    ld a, [queen_neckStatus]
    cp $81
        ret nz
    jp Jump_003_7846

; Prep neck retraction
func_03_78F7: ; 03:78F7
    ld a, [queen_pNeckPatternLow]
    ld l, a
    ld a, [queen_pNeckPatternHigh]
    ld h, a
    ld a, [hl]
    cp $81
    jp z, Jump_003_7846

    ld a, $02
    ld [$c3ba], a
    ld [queen_neckControl], a
    ld a, [queen_headFrame]
    cp $03
    jr nz, jr_003_791c
        ld a, [queen_headY]
        add $10
        ld [queen_headY], a
    jr_003_791c:

    ld a, $01
    ld [queen_headFrameNext], a
    ld [queen_headFrame], a
    ld a, $f5
    ld [$c623], a
    ld a, $05 ; Retracting neck
    ld [queen_state], a
    dec hl
    jp Jump_003_7399

; Retracting neck
func_03_7932: ; 03:7932
    ; Wait until status is $82
    ld a, [queen_neckStatus]
    cp $82
        ret nz
    jp Jump_003_7846

func_03_793B:
    ld a, $02
    ld [queen_walkControl], a
    ld a, $03
    ld [queen_neckControl], a
    xor a
    ld [$c3ba], a
    ld a, $82
    ld [queen_footFrame], a
    ld a, $07 ; Walking backward
    ld [queen_state], a
ret

func_03_7954:
    ld a, [queen_walkStatus]
    cp $82
        ret nz
    xor a
    ld [queen_footFrame], a
    jp Jump_003_7846

; Queen's neck sprite while she is vomiting Samus
table_7961: ; 03:7961
    db $00, $00, $b5
    db $08, $00, $c5
    db $00, $08, $b6
    db $00, $10, $b7
    db $08, $0c, $c6

func_03_7970:
    ld a, [queen_headY]
    cp $2c
    cp $71
    ld a, $01
    ld [queen_neckControl], a
    xor a
    ld [$c3ba], a
    ld a, $03
    ld [queen_headFrameNext], a
    ld [queen_headFrame], a
    ld a, $09 ; Prep spitting Samus out of stomach
    ld [queen_state], a
    ld hl, $c308
    ld a, [queen_headY]
    add $14
    ld b, a
    ld a, [queen_headX]
    add $02
    ld c, a
    ld de, table_7961

    jr_003_799f:
        ld a, [de]
        add b
        ld [hl+], a
        
        inc de
        ld a, [de]
        add c
        ld [hl+], a
        
        inc de
        ld a, [de]
        ld [hl+], a
        
        ld [hl], $80
        inc l
        inc de
        ld a, l
        cp $1c
    jr nz, jr_003_799f

    dec l
    dec l
    dec l
    dec l
    ld a, l
    ld [$c3b8], a
    ld a, h
    ld [$c3b9], a
    ld a, $04 ; Steep neck pattern (barfing samus)
    ld [queen_neckPattern], a
    ld [$c3d1], a
    call Call_003_746f
    call Call_003_7466
    inc hl
    jp Jump_003_7399

func_03_79D0:
    ld a, [queen_neckStatus]
    cp $81
        ret nz
    ld a, $50
    ld [queen_delayTimer], a
    ld a, $0a ; Spitting Samus out
    ld [queen_state], a
ret

func_03_79E1: ; 03:79E1 - Queen spitting Samus out of stomach
    ld a, [queen_delayTimer]
    and a
    jr z, jr_003_79f6
        dec a
        ld [queen_delayTimer], a
        ld a, [queen_footFrame]
        cp $02
            ret nz
        xor a
        ld [queen_footFrame], a
        ret
    jr_003_79f6:
        xor a
        ld [queen_bodyPalette], a
        ld a, [queen_health]
        and a
            jr z, jr_003_7a4d
        sub $1e ; Hurt for 30 damage with bombs
        ld [queen_health], a
            jr c, jr_003_7a4d
        ld a, $02
        ld [queen_neckControl], a
        ld a, $0b ; Done spitting Samus out
        ld [queen_state], a
        ; Set neck pattern
        ld a, [queen_pNeckPatternLow]
        ld l, a
        ld a, [queen_pNeckPatternHigh]
        ld h, a
        dec hl
        jp Jump_003_7399


func_03_7A1D:
    ld a, [queen_neckStatus]
    cp $82
    ret nz

    ld a, $01
    ld [queen_headFrameNext], a
    ld [queen_headFrame], a
    xor a
    ld [$c3d1], a
    ld hl, $c308
    ld b, $05

    jr_003_7a34:
        ld [hl], $ff
        inc l
        inc l
        inc l
        ld [hl], $80
        inc l
        dec b
    jr nz, jr_003_7a34

    ld hl, spriteC300
    ld a, l
    ld [$c3b8], a
    ld a, h
    ld [$c3b9], a
    jp Jump_003_7846


jr_003_7a4d: ; Kill Queen?
    ld b, $0d
    ld hl, $c600
    call Call_003_6e17
    ld a, $01
    ld [queen_neckControl], a
    ld [$c3ba], a
    ld a, $11 ; Prep death
    ld [queen_state], a
    xor a
    ld [$c3b6], a
    ld [$c3b7], a
    ld [$c3d1], a
    ld [queen_health], a
    ld [queen_neckStatus], a
    ld [queen_footFrame], a
    ld [queen_headFrameNext], a
    ld [$c3ef], a
    ld hl, $c308
    ld a, l
    ld [$c3b8], a
    ld a, h
    ld [$c3b9], a
    inc l
    inc l
    inc l
    ld [hl], $80
    inc l
    inc l
    inc l
    inc l
    ld [hl], $80
    call Call_003_7aa8
    ld a, $0f
    ld [sfxRequest_noise], a
    ld a, $05 ; Dying neck pattern
    ld [queen_neckPattern], a
    call Call_003_746f
    call Call_003_7466
    inc hl
    jp Jump_003_7399


Call_003_7aa8:
    ld hl, $9b0e

jr_003_7aab:
    ld a, [rSTAT]
    and $03
    jr nz, jr_003_7aab

    ld [hl], $5d
    inc l

jr_003_7ab5:
    ld a, [rSTAT]
    and $03
    jr nz, jr_003_7ab5

    ld [hl], $5e
    ret

func_03_7ABF:
    ld a, [queen_neckStatus]
    cp $81
        ret nz
    ld a, $50
    ld [queen_delayTimer], a
    ld a, $12 ; Dying part 1 (disintegrating)
    ld [queen_state], a
    ld a, $05
    ld [$c3d5], a
    xor a
    ld [queen_health], a
    ld [$c3d4], a
    ld hl, $c3d6
    ld [hl], $ee
    inc hl
    ld [hl], $bb
    inc hl
    ld [hl], $dd
    inc hl
    ld [hl], $77
    inc hl
    ld [hl], $ee
    inc hl
    ld [hl], $bb
    inc hl
    ld [hl], $dd
    inc hl
    ld [hl], $77
    ld a, $d0
    ld [earthquakeTimer], a
    ; Play earthquake sound
    ld a, $0e
    ld [songRequest], a
    ld a, $22
    ld [queen_eatingState], a
    ret

func_03_7B05: ; State $12
    ld a, [queen_delayTimer]
    and a
    jr z, jr_003_7b1e
        dec a
        ld [queen_delayTimer], a
        cp $4c
            ret nz
        ; Refill Samus health
        ld a, [samusEnergyTanks]
        ld [samusCurHealthHigh], a
        ld a, $99
        ld [samusCurHealthLow], a
        ret
    jr_003_7b1e:

    ld a, [$c3e0]
    and a
        ret nz
    ld de, $c3d6
    ld b, $00
    ld a, [$c3d4]

    jr_003_7b2b:
        cp b
            jr z, jr_003_7b32
        inc de
        inc b
    jr jr_003_7b2b
    jr_003_7b32:

    ld b, a
    or $10
    ld [$c3de], a
    ld a, b
    add $03
    and $07
    ld [$c3d4], a
    jr nz, jr_003_7b4b
        ld a, [$c3d5]
        dec a
        ld [$c3d5], a
        jr z, jr_003_7b59
        jr_003_7b4b:
            ld a, [de]
            rlca
            rlca
            rlca
            ld [de], a
            ld [$c3e0], a
            ld a, $8b
            ld [$c3df], a
            ret
        jr_003_7b59:
            ld a, $a0
            ld [$c3ec], a
            ld a, $99
            ld [$c3ed], a
            ld a, $13 ; Dying part 2
            ld [queen_state], a
            ret

; VBlank Routine
Call_003_7b69:
    ld a, [$c3e0]
    and a
        ret z
    ld b, a
    ld a, [$c3de]
    ld l, a
    ld a, [$c3df]
    ld h, a
    ld de, $0008
    ld c, $1a

    jr_003_7b7c:
        ld a, [hl]
        and b
        ld [hl], a
        add hl, de
        ld a, h
        cp $95
            jr z, jr_003_7b91
      jr_003_7b85:
        dec c
    jr nz, jr_003_7b7c

        ld a, h
        ld [$c3df], a
        ld a, l
        ld [$c3de], a
        ret
    jr_003_7b91:
        ld a, l
        and $f0
        cp $70
            jr nz, jr_003_7b85
        xor a
        ld [$c3e0], a
        ret

func_03_7B9D:
    ld a, [$c3ec]
    ld l, a
    ld a, [$c3ed]
    ld h, a
    ld b, $0b

jr_003_7ba7:
    ld a, [rSTAT]
    and $03
    jr nz, jr_003_7ba7

    ld [hl], $ff

jr_003_7bb0:
    ld a, [rSTAT]
    and $03
    jr nz, jr_003_7bb0

    ld [hl], $ff
    inc hl
    dec b
    jr nz, jr_003_7ba7

    ld de, $0015
    add hl, de
    ld a, l
    cp $80
    jr z, jr_003_7bce

    ld [$c3ec], a
    ld a, h
    ld [$c3ed], a
    ret


jr_003_7bce:
    xor a
    ld [queen_eatingState], a
    ld [metroidCountDisplayed], a
    ld [metroidCountReal], a
    ld a, $16 ; Dying part 3
    ld [queen_state], a
    ld a, $80
    ld [metroidCountShuffleTimer], a
    ld a, $17
    ld [sfxRequest_noise], a
func_03_7BE7: ; State $16
    ret


queen_walk: ; 03:7BE8
    xor a
    ld [queen_walkSpeed], a
    ld a, [queen_walkControl]
    and a
        ret z
    ld b, a
    ld a, [queen_walkWaitTimer]
    and a
    jr z, .else_A
        dec a
        ld [queen_walkWaitTimer], a
        ret
    .else_A:
        ld a, [queen_walkCounter]
        ld l, a
        inc a
        ld [queen_walkCounter], a
        ld h, $00
        ld de, .walkSpeedTable
        add hl, de
        ld a, b
        cp $01
        jr nz, .else_B
            ld a, [hl]
            cp $81
            jr nz, .move
                ld [queen_walkStatus], a
                xor a
                ld [queen_walkControl], a
                ret
                
            .move: ; Common case between the above and below branches
                cpl
                inc a
                ld [queen_walkSpeed], a
                ld a, [hl]
                ld hl, queen_bodyXScroll
                add [hl]
                ld [hl], a
                ret
        
        .else_B:
            ld a, [hl]
            cp $82
                jr nz, .move
            ld [queen_walkStatus], a
            xor a
            ld [queen_walkControl], a
            ld [queen_walkCounter], a
            ret
; end proc

; Values are negated due to how the raster split works
;  $81 means "done walking forward"
;  $82 means "done walking backward"
.walkSpeedTable: ; 03:7C39
    db $ff, $ff, $ff, $ff, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe
    db $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $ff, $ff, $ff
    db $ff, $ff, $81, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02, $02
    db $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02
    db $01, $01, $01, $01, $01, $82

; LCDCInterruptHandler
LCDCInterruptHandler: ; 03:7C7F
    push af ; Caller function already pushed af, so this may be unnecessary
    push bc
    push de
    push hl
    ld a, [queen_pInterruptListLow]
    ld l, a
    ld a, [queen_pInterruptListHigh]
    ld h, a

    .loop:
        ; If token is FF, do nothing and don't set up another interrupt
        ld a, [hl]
        cp $ff
            jr z, .exitLastInterrupt
        and $7f
        cp $01
            jr z, .case_1 ; Set scroll X and palette to queen's
        cp $02
            jr z, .case_2 ; Set scroll X and palette to room's
        cp $03
            jr z, .case_3 ; Disable window (queen's head)
    
        ; case 4 (default) ; Draw status bar
            push hl
                ld hl, rLCDC
                res 5, [hl] ; Disable window
            pop hl
            ; Set scroll for status bar
            xor a
            ld [rSCX], a
            ld a, $70
            ld [rSCY], a
            inc l
        jr .exitLastInterrupt
        
        .case_3: ; Disable window
            push hl
            ld hl, rLCDC
            res 5, [hl]
            pop hl
        jr .nextToken
        
        .case_1:
            ld a, [queen_bodyXScroll]
            ld [rSCX], a
            ld a, [queen_bodyPalette]
            and a
                jr z, .nextToken
            ld [rBGP], a
        jr .nextToken
        
        .case_2:
            ld a, [scrollX]
            ld [rSCX], a
            ld a, $93 ; FIXME: Causes palette issues if pausing is enabled
            ld [rBGP], a
        ; end case
    
    .nextToken:
        bit 7, [hl]
            jr z, .exitAndPrepNextInterrupt
        inc l
        inc l
    jr .loop

.exitAndPrepNextInterrupt:
    ; Load Y position for next interrupt
    inc l
    ld a, [hl+]
    ld [rLYC], a
.exitLastInterrupt:
    ; Save interrupt instruction pointer
    ld a, l
    ld [queen_pInterruptListLow], a
    ld a, h
    ld [queen_pInterruptListHigh], a
    pop hl
    pop de
    pop bc
    pop af
ret


VBlank_drawQueen: ; 03:7CF0
    call queen_drawFeet ; Also draws head if no foot animation is ready
    call Call_003_7b69 ; Disintegration effect?
    ; Set scroll position
    ld a, [scrollX]
    ld [rSCX], a
    ld a, [scrollY]
    ld [rSCY], a
    ; Set head X position
    ld a, [queen_headX]
    cp $a6
    jr nz, .endIf_A
        ld a, $a7
    .endIf_A:
    ld [rWX], a
; Start preparing the interrupt list
    ; Set head Y position
    ld a, [queen_headY]
    ld [rWY], a
    add $26
    cp $90
    jr c, .endIf_B
        ld a, $8f
    .endIf_B:
    ld [queen_headBottomY], a
    
    ld a, [queen_bodyY]
    ld b, a
    ld a, [queen_bodyHeight]
    add b
    cp $90
    jr c, .endIf_C
        ld a, $8f
    .endIf_C:
    ld d, a
    
    ld hl, queen_interruptList
    ld a, [queen_headBottomY]
    ld b, a
    ld a, [queen_bodyY]
    sub b
    jr c, .elseIf_D
        ; Decide whether "disable window" is the only interrupt for its scanline or not
        ld c, $83
        jr z, .endIf_E
            ld c, $03
        .endIf_E:
        ; Write y pos of initial interrupt
        ld [hl], b
        ; Set interrupt type to "disable window"
        inc l
        ld [hl], c
        ; Set y pos of 2nd interrupt to the top of the queen's body
        inc l
        ld a, [queen_bodyY]
        ld [hl+], a
        ; Set interrupt tyoe to "queen's body"
        ld [hl], $01
        ; Set the ypos of the 3rd interrupt to the bottom of the queen's body
        inc l
        ld [hl], d
        ; Set interrupt type to "restore room"
        inc l
        ld [hl], $02
        jr .endIf_D
    .elseIf_D:
    
    ld a, b
    sub d
    jr c, .else_D
        ; Decide whether the "restore room" command will be the only iterrupt on its scanline
        ld c, $82
        jr z, .endIf_F
            ld c, $02
        .endIf_F:
        ; Set the y position of the initial interrupt to the top of the queen's body
        ld a, [queen_bodyY]
        ld [hl+], a
        ; Set initial interrupt type to "queen's body"
        ld [hl], $01
        ; Set the ypos of next interrupt to the bottom of the queen's body
        inc l
        ld [hl], d
        ; Set interrupt type to "restore room"
        inc l
        ld [hl], c
        ; Set y pos of next interrupt to bottom of Queen's head
        inc l
        ld a, [queen_headBottomY]
        ld [hl+], a
        ; Set interrupt type to "disable window"
        ld [hl], $03
        jr .endIf_D
    .else_D:
        ; Set y pos of inital interrupt to top of queen's body
        ld a, [queen_bodyY]
        ld [hl+], a
        ; Set interrupt type to "queen's body"
        ld [hl], $01
        ; Set y pos of 2nd interrupt to bottom of queen's head
        inc l
        ld a, [queen_headBottomY]
        ld [hl+], a
        ; Set interrupt type to "disable window"
        ld [hl], $03
        ; Set y pos of 3rd interrupt to bottom of queen's body
        inc l
        ld [hl], d
        ; Set interrupt type to "restore room"
        inc l
        ld [hl], $02
    .endIf_D:

; This displays the status bar by finding the first interrupt command with a scanline of 87 or greater and replacing it.
    ld b, $03
    ld hl, queen_interruptList
    .loop:
        ld a, [hl]
        cp $87
            jr nc, .break
        inc l
        inc l
        dec b
    jr nz, .loop
    .break:
    ; Set y position of last interrupt to $87 (scanline 135)
    ld [hl], $87
    ; Set interrupt type to "status bar"
    inc l
    ld [hl], $04
    ; Add interrupt list terminator
    inc l
    ld [hl], $ff
    ; Prep initial interrupt
    ld hl, queen_interruptList
    ld a, [hl+]
    ld [rLYC], a
    ; Prep interrupt pointer
    ld a, l
    ld [queen_pInterruptListLow], a
    ld a, h
    ld [queen_pInterruptListHigh], a
    ; Enable window display
    ld hl, rLCDC
    set 5, [hl]
ret

bank3_freespace: ; 3:7DAD -- Freespace filled with $00 (nop)
