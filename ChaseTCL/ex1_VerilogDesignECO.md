# 연습문제1: Verilog Design ECO

## TCL 고급 연습문제: Verilog Buffer Chain 분석 및 수정 🔧📊

### 문제 설명

주어진 Verilog 파일에는 HVT(High Voltage Threshold)와 LVT(Low Voltage Threshold) 버퍼 셀이 혼합되어 있습니다. 당신의 임무는 이 파일을 분석하고, 모든 버퍼를 LVT로 교체한 새 파일을 생성하는 것입니다.

### 요구사항

1. 'origin.v' 파일에서 버퍼 체인 Verilog 코드를 읽습니다.
2. HVT와 LVT 버퍼 셀의 각 개수를 세고 보고합니다.
3. 모든 버퍼 셀을 LVT 버퍼로 교체합니다.
4. 수정된 Verilog 코드를 'lvt.v' 파일에 저장합니다.
5. 변경된 셀의 수를 보고합니다.

### 입력 파일 예시 (origin.v)

```verilog
module buffer_chain (
    input wire in,
    output wire out
);

    wire w1, w2, w3, w4, w5;

    BUFX1_HVT buf1 (.A(in), .Y(w1));
    BUFX1_LVT buf2 (.A(w1), .Y(w2));
    BUFX4_HVT buf3 (.A(w2), .Y(w3));
    BUFX1_LVT buf4 (.A(w3), .Y(w4));
    BUFX2_HVT buf5 (.A(w4), .Y(w5));
    BUFX1_LVT buf6 (.A(w5), .Y(out));

endmodule
```

### 예상 출력 파일 내용 (lvt.v)

```verilog
module buffer_chain (
    input wire in,
    output wire out
);

    wire w1, w2, w3, w4, w5;

    BUFX1_LVT buf1 (.A(in), .Y(w1));
    BUFX1_LVT buf2 (.A(w1), .Y(w2));
    BUFX4_LVT buf3 (.A(w2), .Y(w3));
    BUFX1_LVT buf4 (.A(w3), .Y(w4));
    BUFX2_LVT buf5 (.A(w4), .Y(w5));
    BUFX1_LVT buf6 (.A(w5), .Y(out));

endmodule
```

### 콘솔 출력 예시

```
HVT: 3
LVT: 3
```

###
