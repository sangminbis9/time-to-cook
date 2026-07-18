#!/usr/bin/env bash
# 통합 테스트 러너: headless Godot 인스턴스 2개(호스트+게스트)를 localhost ENet으로
# 띄워 시나리오를 수행한다.
# 사용: bash run_net_tests.sh [시나리오...]   (인자 없으면 전체)
set -u

GODOT="${GODOT:-$HOME/godot/godot}"
GAME_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RESULT_DIR="$(mktemp -d)"
ALL_SCENARIOS=(simultaneous_pickup coop_cook_submit day_loop fridge host_quit employee employee_roster employee_roles employee_support staff_transfer economy loans ads multi_store independent_stores city_layouts character_skill store_events prevention sauce_menu station_edit market char_info research insurance dynamic_economy econ_events save_write save_load)
# 솔로 시나리오: 호스트 인스턴스 하나만 필요 (세이브 쓰기→재시작 로드 순서 중요)
SOLO_SCENARIOS="employee employee_roster employee_roles employee_support staff_transfer economy loans ads multi_store city_layouts character_skill store_events prevention sauce_menu station_edit market char_info research insurance dynamic_economy econ_events save_write save_load"
SCENARIOS=("${@:-${ALL_SCENARIOS[@]}}")
PORT_BASE=17700
FAILED=0

is_solo() { case " $SOLO_SCENARIOS " in *" $1 "*) return 0;; *) return 1;; esac; }

for i in "${!SCENARIOS[@]}"; do
  SCENARIO="${SCENARIOS[$i]}"
  PORT=$((PORT_BASE + i))
  HOST_RESULT="$RESULT_DIR/${SCENARIO}_host.json"
  GUEST_RESULT="$RESULT_DIR/${SCENARIO}_guest.json"

  echo "── 시나리오: $SCENARIO (port $PORT)"
  "$GODOT" --headless --path "$GAME_DIR" -- \
    --nettest=host --scenario="$SCENARIO" --port="$PORT" \
    --result="$HOST_RESULT" > "$RESULT_DIR/${SCENARIO}_host.log" 2>&1 &
  HOST_PID=$!
  GUEST_EXIT=0
  if ! is_solo "$SCENARIO"; then
    sleep 2
    "$GODOT" --headless --path "$GAME_DIR" -- \
      --nettest=guest --scenario="$SCENARIO" --port="$PORT" \
      --result="$GUEST_RESULT" > "$RESULT_DIR/${SCENARIO}_guest.log" 2>&1 &
    GUEST_PID=$!
    wait "$GUEST_PID"; GUEST_EXIT=$?
  fi
  wait "$HOST_PID"; HOST_EXIT=$?

  if [ "$HOST_EXIT" -eq 0 ] && [ "$GUEST_EXIT" -eq 0 ]; then
    echo "   PASS (host=$HOST_EXIT guest=$GUEST_EXIT)"
  else
    echo "   FAIL (host=$HOST_EXIT guest=$GUEST_EXIT)"
    echo "   ── host 로그 꼬리:"; tail -5 "$RESULT_DIR/${SCENARIO}_host.log" | sed 's/^/      /'
    echo "   ── guest 로그 꼬리:"; tail -5 "$RESULT_DIR/${SCENARIO}_guest.log" | sed 's/^/      /'
    FAILED=1
  fi
done

echo "결과 디렉터리: $RESULT_DIR"
exit $FAILED
