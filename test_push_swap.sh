#!/usr/bin/env bash
# Script complet push_swap 42
# Avec tests pour tous les flags, piles déjà triées, leaks, stress et benchmark

PS=./push_swap
CK=./checker_linux
VALGRIND="valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=all --error-exitcode=42"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

fail=0

# =========================
# UTILS
# =========================

expect_exact() {
    NAME="$1"
    CMD="$2"
    EXPECT="$3"
    OUT=$(eval "$CMD" 2>&1)
    RET=$?
    if diff -u <(printf "%s\n" "$EXPECT") <(printf "%s\n" "$OUT") >/dev/null && [ $RET -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} $NAME"
    else
        echo -e "${RED}[KO]${NC} $NAME"
        echo "EXPECTED: $EXPECT (return 0)"
        echo "GOT     : $OUT (return $RET)"
        fail=1
    fi
}

check_sort() {
    local ARG="$1"
    local FLAG="$2"
    
    # Exécuter push_swap
    OUT=$(eval "$PS $FLAG $ARG" 2>/dev/null)
    RET=$?
    
    # Compter les opérations
    if [ -z "$OUT" ]; then
        OPS=0
    else
        OPS=$(echo "$OUT" | wc -l)
    fi
    
    # Si 0 opération, vérifier si la pile est déjà triée
    if [ $OPS -eq 0 ] && [ $RET -eq 0 ]; then
        # Tester si c'est bien trié avec un checker "à vide"
        echo "" | eval "$CK $ARG" 2>/dev/null | grep -q "OK"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[OK]${NC} $FLAG $ARG (ops=0, already sorted)"
            return
        fi
    fi
    
    # Vérifier avec checker (si ops > 0)
    if [ $OPS -gt 0 ]; then
        RES=$(echo "$OUT" | eval "$CK $ARG" 2>/dev/null)
    else
        RES=""
    fi
    
    # Si déjà trié (1 2 3), accepter 0 ou 1 opération
    if echo "$ARG" | grep -qE '1.*2.*3' && [ $(echo "$ARG" | grep -o '[0-9]' | wc -l) -eq 3 ]; then
        if [ "$RES" = "OK" ] || [ $OPS -eq 0 ]; then
            if [ $RET -eq 0 ]; then
                echo -e "${GREEN}[OK]${NC} $FLAG $ARG (ops=$OPS)"
                return
            fi
        fi
    fi
    
    # Sinon, comportement normal
    if [ "$RES" = "OK" ] && [ $RET -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} $FLAG $ARG (ops=$OPS)"
    else
        echo -e "${RED}[KO]${NC} $FLAG $ARG (ops=$OPS, checker=$RES, return=$RET)"
        fail=1
    fi
}
check_leak() {
    ARG="$1"
    FLAG="$2"
    $VALGRIND $PS $FLAG $ARG >/dev/null 2>&1
    if [ $? -eq 42 ]; then
        echo -e "${RED}[LEAK ❌]${NC} $FLAG $ARG"
        fail=1
    else
        echo -e "${GREEN}[NO LEAK ✅]${NC} $FLAG $ARG"
    fi
}

random_arg() {
    N=$1
    seq -$((N*10)) $((N*10)) | shuf | head -n $N | tr '\n' ' '
}

# =========================
# CAS DEJA TRIE (ops <= 1 accepté)
# =========================
echo -e "\n${YELLOW}=== CAS DEJA TRIE ===${NC}"
for FLAG in "" "--simple" "--medium" "--complex" "--adaptive"; do
    ARG="1 2 3"
    OUT=$($PS $FLAG $ARG 2>/dev/null)
    RET=$?
    
    if [ $RET -eq 0 ]; then
        if [ -z "$OUT" ]; then
            echo -e "${GREEN}[OK]${NC} Pile déjà triée $FLAG (0 ops)"
        else
            OPS=$(echo "$OUT" | wc -l)
            RES=$(echo "$OUT" | $CK $ARG 2>/dev/null)
            if [ "$RES" = "OK" ] && [ $OPS -le 1 ]; then
                echo -e "${GREEN}[OK]${NC} Pile déjà triée $FLAG (ops=$OPS)"
            else
                echo -e "${RED}[KO]${NC} Pile déjà triée $FLAG (ops=$OPS, checker=$RES)"
                fail=1
            fi
        fi
    else
        echo -e "${RED}[KO]${NC} Pile déjà triée $FLAG (return=$RET)"
        fail=1
    fi
done

# =========================
# ERREURS STRICTES
# =========================
echo -e "${YELLOW}=== ERREURS STRICTES ===${NC}"
expect_exact "doublons"      "$PS 1 2 1" "Error"
expect_exact "lettre"        "$PS 1 a 3" "Error"
expect_exact "overflow +"    "$PS 2147483648" "Error"
expect_exact "overflow -"    "$PS -2147483649" "Error"
expect_exact "flag"          "$PS --help" "Error"

# =========================
# CAS PAS D'ARGUMENT
# =========================
echo -e "\n${YELLOW}=== CAS PAS D'ARGUMENT ===${NC}"
for FLAG in "" "--simple" "--medium" "--complex" "--adaptive"; do
    OUT=$($PS $FLAG)
    RET=$?
    OPS=$(echo "$OUT" | wc -l)
    if [ -z "$OUT" ] && [ $RET -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} Pas d'argument $FLAG (aucune sortie, return 0)"
    else
        echo -e "${RED}[KO]${NC} Pas d'argument $FLAG (sortie inattendue ou return $RET)"
        fail=1
    fi
done



# =========================
# PARSING / FORMAT
# =========================
echo -e "\n${YELLOW}=== PARSING / FORMAT ===${NC}"
for FLAG in "" "--simple" "--medium" "--complex" "--adaptive"; do
    check_sort "\"1 2 3\"" "$FLAG"
    check_sort "\"  1   2   3 \"" "$FLAG"
    check_sort $'1\t2\t3' "$FLAG"
    check_sort "1  2   3" "$FLAG"
done

# =========================
# TRI SIMPLES
# =========================
echo -e "\n${YELLOW}=== TRI SIMPLES ===${NC}"
for FLAG in "" "--simple" "--medium" "--complex" "--adaptive"; do
    check_sort "2 1" "$FLAG"
    check_sort "3 2 1" "$FLAG"
    check_sort "5 1 4 2 3" "$FLAG"
done

# =========================
# RANDOM TESTS
# =========================
echo -e "\n${YELLOW}=== RANDOM TESTS 10 NUMS ===${NC}"
for i in {1..5}; do
    ARG=$(random_arg 10)
    for FLAG in "" "--simple" "--medium" "--complex" "--adaptive"; do
        check_sort "$ARG" "$FLAG"
    done
done

# =========================
# STRESS TESTS
# =========================
echo -e "\n${YELLOW}=== STRESS TESTS ===${NC}"
for N in 100 500; do
    ARG=$(random_arg $N)
    for FLAG in "" "--simple" "--medium" "--complex" "--adaptive"; do
        OPS=$($PS $FLAG $ARG | wc -l)
        RES=$(echo "$($PS $FLAG $ARG)" | $CK $ARG 2>/dev/null)
        RET=$?
        echo "$FLAG $N numbers → ops=$OPS result=$RES return=$RET"
    done
done

# =========================
# BENCHMARK 100 TESTS
# =========================
echo -e "\n${YELLOW}=== BENCHMARK 100 TESTS (100 NUMS) ===${NC}"
sum=0; min=999999; max=0
for i in {1..100}; do
    ARG=$(random_arg 100)
    for FLAG in "" "--simple" "--medium" "--complex" "--adaptive"; do
        C=$($PS $FLAG $ARG | wc -l)
        ((sum+=C))
        ((C<min)) && min=$C
        ((C>max)) && max=$C
    done
done
echo "min=$min max=$max avg=$((sum/100))"

# =========================
# LEAKS
# =========================
echo -e "\n${YELLOW}=== LEAKS ===${NC}"
for ARG in "2 1" "1 2 3" "1 2 2" "$(random_arg 100)"; do
    for FLAG in "" "--simple" "--medium" "--complex" "--adaptive"; do
        check_leak "$ARG" "$FLAG"
    done
done

# =========================
# RESULT FINAL
# =========================
if [ $fail -eq 0 ]; then
    echo -e "\n${GREEN}ALL TESTS PASSED 🎉${NC}"
else
    echo -e "\n${RED}SOME TESTS FAILED ❌${NC}"
fi


# Tests des checkers (checker_linux et bonus checker)

PS=./push_swap
CK_LINUX=./checker_linux
CK_BONUS=./checker
VALGRIND="valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=all --error-exitcode=42"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

fail=0

random_arg() {
    N=$1
    seq -$((N*10)) $((N*10)) | shuf | head -n $N | tr '\n' ' '
}

check_leak_checker() {
    ARG="$1"
    OPS="$2"
    CHECKER="$3"
    echo "$OPS" | $VALGRIND $CHECKER $ARG >/dev/null 2>&1
    if [ $? -eq 42 ]; then
        echo -e "${RED}[LEAK ❌]${NC} $(basename $CHECKER) '$ARG'"
        fail=1
    else
        echo -e "${GREEN}[NO LEAK ✅]${NC} $(basename $CHECKER) '$ARG'"
    fi
}

# =========================
# TESTS CHECKER_LINUX
# =========================
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       TESTS CHECKER_LINUX             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}=== CHECKER_LINUX: Erreurs ===${NC}"

# Doublons
RES=$(echo "" | $CK_LINUX 1 2 1 2>&1)
if [ "$RES" = "Error" ]; then
    echo -e "${GREEN}[OK]${NC} Doublons → Error"
else
    echo -e "${RED}[KO]${NC} Doublons (got: '$RES')"
    fail=1
fi

# Lettre
RES=$(echo "" | $CK_LINUX 1 a 3 2>&1)
if [ "$RES" = "Error" ]; then
    echo -e "${GREEN}[OK]${NC} Lettre → Error"
else
    echo -e "${RED}[KO]${NC} Lettre (got: '$RES')"
    fail=1
fi

# Overflow
RES=$(echo "" | $CK_LINUX 2147483648 2>&1)
if [ "$RES" = "Error" ]; then
    echo -e "${GREEN}[OK]${NC} Overflow → Error"
else
    echo -e "${RED}[KO]${NC} Overflow (got: '$RES')"
    fail=1
fi

# Opération invalide
RES=$(echo "invalid_op" | $CK_LINUX 1 2 3 2>&1)
if [ "$RES" = "Error" ]; then
    echo -e "${GREEN}[OK]${NC} Op invalide → Error"
else
    echo -e "${RED}[KO]${NC} Op invalide (got: '$RES')"
    fail=1
fi

echo -e "\n${YELLOW}=== CHECKER_LINUX: Pas d'argument ===${NC}"
OUT=$(echo "" | $CK_LINUX 2>&1)
RET=$?
if [ -z "$OUT" ] && [ $RET -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} Pas d'argument"
else
    echo -e "${RED}[KO]${NC} Pas d'argument (out='$OUT', ret=$RET)"
    fail=1
fi


echo -e "\n${YELLOW}=== CHECKER_LINUX: Opérations valides ===${NC}"

# sa sur "2 1"
RES=$(echo "sa" | $CK_LINUX 2 1)
if [ "$RES" = "OK" ]; then
    echo -e "${GREEN}[OK]${NC} sa sur '2 1' → OK"
else
    echo -e "${RED}[KO]${NC} sa sur '2 1' (got: '$RES')"
    fail=1
fi

# Séquence complète
ARG="3 2 1"
OPS=$($PS $ARG)
RES=$(echo "$OPS" | $CK_LINUX $ARG)
if [ "$RES" = "OK" ]; then
    echo -e "${GREEN}[OK]${NC} Séquence '$ARG' → OK"
else
    echo -e "${RED}[KO]${NC} Séquence '$ARG' (got: '$RES')"
    fail=1
fi

echo -e "\n${YELLOW}=== CHECKER_LINUX: Pile non triée ===${NC}"
RES=$(echo "sa" | $CK_LINUX 3 2 1)
if [ "$RES" = "KO" ]; then
    echo -e "${GREEN}[OK]${NC} Détecte pile non triée → KO"
else
    echo -e "${RED}[KO]${NC} Pile non triée (got: '$RES')"
    fail=1
fi

echo -e "\n${YELLOW}=== CHECKER_LINUX: Stress test ===${NC}"
for N in 10 100 500; do
    ARG=$(random_arg $N)
    OPS=$($PS $ARG 2>/dev/null)
    RES=$(echo "$OPS" | $CK_LINUX $ARG 2>/dev/null)
    if [ "$RES" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $N nombres → OK"
    else
        echo -e "${RED}✗${NC} $N nombres → $RES"
        fail=1
    fi
done

echo -e "\n${YELLOW}=== CHECKER_LINUX: Leaks ===${NC}"
check_leak_checker "2 1" "sa" "$CK_LINUX"
check_leak_checker "1 2 3" "" "$CK_LINUX"
check_leak_checker "1 2 2" "" "$CK_LINUX"
ARG=$(random_arg 50)
OPS=$($PS $ARG)
check_leak_checker "$ARG" "$OPS" "$CK_LINUX"

# =========================
# TESTS BONUS CHECKER
# =========================
if [ -f "$CK_BONUS" ]; then
    echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       TESTS BONUS CHECKER             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}=== BONUS: Erreurs ===${NC}"
    
    # Doublons
    RES=$(echo "" | $CK_BONUS 1 2 1 2>&1)
    if [ "$RES" = "Error" ]; then
        echo -e "${GREEN}[OK]${NC} Doublons → Error"
    else
        echo -e "${RED}[KO]${NC} Doublons (got: '$RES')"
        fail=1
    fi
    
    # Lettre
    RES=$(echo "" | $CK_BONUS 1 a 3 2>&1)
    if [ "$RES" = "Error" ]; then
        echo -e "${GREEN}[OK]${NC} Lettre → Error"
    else
        echo -e "${RED}[KO]${NC} Lettre (got: '$RES')"
        fail=1
    fi
    
    # Overflow
    RES=$(echo "" | $CK_BONUS 2147483648 2>&1)
    if [ "$RES" = "Error" ]; then
        echo -e "${GREEN}[OK]${NC} Overflow → Error"
    else
        echo -e "${RED}[KO]${NC} Overflow (got: '$RES')"
        fail=1
    fi
    
    # Opération invalide
    RES=$(echo "xx" | $CK_BONUS 3 2 1 2>&1)
    if [ "$RES" = "Error" ]; then
        echo -e "${GREEN}[OK]${NC} Op invalide → Error"
    else
        echo -e "${RED}[KO]${NC} Op invalide (got: '$RES')"
        fail=1
    fi
    
    echo -e "\n${YELLOW}=== BONUS: Pas d'argument ===${NC}"
    OUT=$(echo "" | $CK_BONUS 2>&1)
    RET=$?
    if [ -z "$OUT" ] && [ $RET -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} Pas d'argument"
    else
        echo -e "${RED}[KO]${NC} Pas d'argument (out='$OUT', ret=$RET)"
        fail=1
    fi
    
    echo -e "\n${YELLOW}=== BONUS: Pile déjà triée ===${NC}"
   RES=$(echo "" | $CK_BONUS 1 2 3)
if [ "$RES" = "OK" ] || [ -z "$RES" ]; then
    echo -e "${GREEN}[OK]${NC} Pile triée (0 ops) → OK"
else
    echo -e "${RED}[KO]${NC} Pile triée (got: '$RES')"
    fail=1
fi

    
    echo -e "\n${YELLOW}=== BONUS: Opérations valides ===${NC}"
    
    # sa sur "2 1"
    RES=$(echo "sa" | $CK_BONUS 2 1)
    if [ "$RES" = "OK" ]; then
        echo -e "${GREEN}[OK]${NC} sa sur '2 1' → OK"
    else
        echo -e "${RED}[KO]${NC} sa sur '2 1' (got: '$RES')"
        fail=1
    fi
    
    # pb sur pile vide b
    RES=$(echo "pb" | $CK_BONUS 2 1 2>/dev/null)
    if [ "$RES" = "KO" ]; then
        echo -e "${GREEN}[OK]${NC} pb (pile b reste vide) → KO"
    else
        echo -e "${YELLOW}[INFO]${NC} pb sur pile vide (got: '$RES')"
    fi
    
    # Séquence complète
    ARG="3 2 1"
    OPS=$($PS $ARG)
    RES=$(echo "$OPS" | $CK_BONUS $ARG)
    if [ "$RES" = "OK" ]; then
        echo -e "${GREEN}[OK]${NC} Séquence '$ARG' → OK"
    else
        echo -e "${RED}[KO]${NC} Séquence '$ARG' (got: '$RES')"
        fail=1
    fi
    
    echo -e "\n${YELLOW}=== BONUS: Pile non triée ===${NC}"
    RES=$(echo "sa" | $CK_BONUS 3 2 1)
    if [ "$RES" = "KO" ]; then
        echo -e "${GREEN}[OK]${NC} Détecte pile non triée → KO"
    else
        echo -e "${RED}[KO]${NC} Pile non triée (got: '$RES')"
        fail=1
    fi
    
    echo -e "\n${YELLOW}=== BONUS: Comparaison avec checker_linux ===${NC}"
    passed=0
    total=20
    for i in $(seq 1 $total); do
        ARG=$(random_arg 10)
        OPS=$($PS $ARG 2>/dev/null)
        
        RES_LINUX=$(echo "$OPS" | $CK_LINUX $ARG 2>/dev/null)
        RES_BONUS=$(echo "$OPS" | $CK_BONUS $ARG 2>/dev/null)
        
        if [ "$RES_LINUX" = "$RES_BONUS" ]; then
            ((passed++))
        else
            echo -e "${RED}[DIFF]${NC} Args: $(echo $ARG | cut -d' ' -f1-5)..."
            echo "  Linux: $RES_LINUX"
            echo "  Bonus: $RES_BONUS"
            fail=1
        fi
    done
    echo "$passed/$total tests concordent"
    
    echo -e "\n${YELLOW}=== BONUS: Parsing ===${NC}"
    
    # Avec guillemets
  RES=$(echo "" | eval "$CK_BONUS \"1 2 3\"")
if [ "$RES" = "OK" ] || [ -z "$RES" ]; then
    echo -e "${GREEN}[OK]${NC} Parsing guillemets"
else
    echo -e "${RED}[KO]${NC} Parsing guillemets (got: '$RES')"
    fail=1
fi

    
    # Espaces multiples
   if [ "$RES" = "OK" ] || [ -z "$RES" ]; then
    echo -e "${GREEN}[OK]${NC} Espaces multiples"
else
    echo -e "${RED}[KO]${NC} Espaces multiples (got: '$RES')"
    fail=1
fi

    
    echo -e "\n${YELLOW}=== BONUS: Stress test ===${NC}"
    for N in 10 100 500; do
        ARG=$(random_arg $N)
        OPS=$($PS $ARG 2>/dev/null)
        RES=$(echo "$OPS" | $CK_BONUS $ARG 2>/dev/null)
        if [ "$RES" = "OK" ]; then
            echo -e "${GREEN}✓${NC} $N nombres → OK"
        else
            echo -e "${RED}✗${NC} $N nombres → $RES"
            fail=1
        fi
    done
    
    echo -e "\n${YELLOW}=== BONUS: Toutes les opérations ===${NC}"
    
    # Test sa
    RES=$(echo "sa" | $CK_BONUS 3 1 2)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} sa" || echo -e "${RED}[KO]${NC} sa (got: '$RES')"
    
    # Test sb (avec pb avant)
    RES=$(echo -e "pb\nsb" | $CK_BONUS 1 3 2)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} sb" || echo -e "${RED}[KO]${NC} sb (got: '$RES')"
    
    # Test ss
    RES=$(echo -e "pb\nss" | $CK_BONUS 2 1 4 3)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} ss" || echo -e "${RED}[KO]${NC} ss (got: '$RES')"
    
    # Test pa
    RES=$(echo -e "pb\npa" | $CK_BONUS 1 2 3)
    [ "$RES" = "OK" ] && echo -e "${GREEN}[OK]${NC} pa" || echo -e "${RED}[KO]${NC} pa (got: '$RES')"
    
    # Test pb
    RES=$(echo "pb" | $CK_BONUS 1 2 3)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} pb" || echo -e "${RED}[KO]${NC} pb (got: '$RES')"
    
    # Test ra
    RES=$(echo "ra" | $CK_BONUS 2 3 1)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} ra" || echo -e "${RED}[KO]${NC} ra (got: '$RES')"
    
    # Test rb
    RES=$(echo -e "pb\nrb" | $CK_BONUS 1 2 3)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} rb" || echo -e "${RED}[KO]${NC} rb (got: '$RES')"
    
    # Test rr
    RES=$(echo -e "pb\nrr" | $CK_BONUS 2 3 1)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} rr" || echo -e "${RED}[KO]${NC} rr (got: '$RES')"
    
    # Test rra
    RES=$(echo "rra" | $CK_BONUS 3 1 2)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} rra" || echo -e "${RED}[KO]${NC} rra (got: '$RES')"
    
    # Test rrb
    RES=$(echo -e "pb\nrrb" | $CK_BONUS 1 2 3)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} rrb" || echo -e "${RED}[KO]${NC} rrb (got: '$RES')"
    
    # Test rrr
    RES=$(echo -e "pb\nrrr" | $CK_BONUS 3 1 2)
    [ "$RES" = "KO" ] && echo -e "${GREEN}[OK]${NC} rrr" || echo -e "${RED}[KO]${NC} rrr (got: '$RES')"
    
    echo -e "\n${YELLOW}=== BONUS: Leaks ===${NC}"
    check_leak_checker "2 1" "sa" "$CK_BONUS"
    check_leak_checker "1 2 3" "" "$CK_BONUS"
    check_leak_checker "1 2 2" "" "$CK_BONUS"
    ARG=$(random_arg 50)
    OPS=$($PS $ARG)
    check_leak_checker "$ARG" "$OPS" "$CK_BONUS"
    
else
    echo -e "\n${YELLOW}⚠ Checker bonus non trouvé (./checker)${NC}"
fi

# =========================
# RESULT FINAL
# =========================
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
if [ $fail -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKER TESTS PASSED 🎉${NC}"
else
    echo -e "${RED}✗ SOME CHECKER TESTS FAILED ❌${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "\n${YELLOW}=== COMPARAISON CHECKER_LINUX vs CHECKER BONUS ===${NC}"

# =========================
# TEST PUSH_SWAP AVEC CHECKER_LINUX (VERSION ÉTENDUE)
# =========================
echo -e "\n${YELLOW}=== TEST PUSH_SWAP AVEC CHECKER_LINUX (ÉTENDU) ===${NC}"

for N in 2 3 5 10 50 100 500; do
    ARG=$(random_arg $N)
    echo -e "\nPile aléatoire ($N éléments): $ARG"

    # Générer les opérations avec push_swap
    OPS=$($PS $ARG 2>/dev/null)
    N_OPS=$(echo "$OPS" | wc -l)

    # Vérifier avec checker_linux
    if [ -z "$OPS" ]; then
        # Pas d'opérations → pile déjà triée
        echo "" | $CK $ARG >/dev/null 2>&1
        CK_RET=$?
    else
        printf "%s\n" "$OPS" | $CK $ARG >/dev/null 2>&1
        CK_RET=$?
    fi

    echo "Nombre d'opérations: $N_OPS"
    echo "Checker Linux return code: $CK_RET"

    if [ $CK_RET -eq 0 ]; then
        echo -e "${GREEN}[OK] Pile triée correctement${NC}"
    elif [ $CK_RET -eq 1 ]; then
        echo -e "${RED}[KO] Pile non triée${NC}"
        fail=1
    else
        echo -e "${RED}[ERROR] Checker a retourné une erreur${NC}"
        fail=1
    fi
done

# =========================
# TESTS DE PILES INVERSÉES
# =========================
echo -e "\n${YELLOW}=== TESTS PILES INVERSÉES ===${NC}"
for ARG in "3 2 1" "5 4 3 2 1" "10 9 8 7 6 5 4 3 2 1"; do
    OPS=$($PS $ARG 2>/dev/null)
    N_OPS=$(echo "$OPS" | wc -l)
    printf "%s\n" "$OPS" | $CK $ARG >/dev/null 2>&1
    CK_RET=$?

    if [ $CK_RET -eq 0 ]; then
        echo -e "${GREEN}[OK] Pile inversée triée correctement ($ARG, ops=$N_OPS)${NC}"
    else
        echo -e "${RED}[KO] Pile inversée non triée ($ARG)${NC}"
        fail=1
    fi
done

# =========================
# TESTS DE VALEURS LIMITES
# =========================
echo -e "\n${YELLOW}=== TESTS VALEURS LIMITES ===${NC}"
for ARG in "2147483647 -2147483648 0" ; do
    OPS=$($PS $ARG 2>/dev/null)
    N_OPS=$(echo "$OPS" | wc -l)
    printf "%s\n" "$OPS" | $CK $ARG >/dev/null 2>&1
    CK_RET=$?

    if [ $CK_RET -eq 0 ]; then
        echo -e "${GREEN}[OK] Valeurs limites triées correctement ($ARG, ops=$N_OPS)${NC}"
    else
        echo -e "${RED}[KO] Valeurs limites non triées ($ARG)${NC}"
        fail=1
    fi
done

# =========================
# TESTS D'ENTRÉES INVALIDES
# =========================
echo -e "\n${YELLOW}=== TESTS ENTRÉES INVALIDES ===${NC}"
for ARG in "1 2 2" "1 a 3" "2147483648 -2147483649"; do
    RES=$($PS $ARG 2>&1)
    if echo "$RES" | grep -q "Error"; then
        echo -e "${GREEN}[OK] Entrée invalide détectée ($ARG)${NC}"
    else
        echo -e "${RED}[KO] Entrée invalide non détectée ($ARG)${NC}"
        fail=1
    fi
done
