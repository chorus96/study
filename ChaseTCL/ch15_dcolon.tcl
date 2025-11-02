#!/usr/bin/tclsh

# # 15장: Double colon

# ### 1. 이중 콜론(::) 개요

# TCL에서 이중 콜론(::)은 다음과 같은 용도로 사용됩니다:

# 1. 전역 네임스페이스 지정
# 2. 네임스페이스 구분
# 3. 정규화된(fully qualified) 이름 생성

# ### 2. 전역 네임스페이스 지정

# 이중 콜론을 이름 앞에 사용하면 전역 네임스페이스의 변수나 프로시저를 참조합니다.

# ```tcl
set ::globalVar 10

proc localScope {} {
    puts $::globalVar  ;# 전역 변수 접근
}

localScope  ;# 출력: 10
# ```

# ### 3. 네임스페이스 구분

# 이중 콜론은 네임스페이스를 구분하는 데 사용됩니다.

# ```tcl
namespace eval MyNamespace {
    variable myVar 20
    
    proc myProc {} {
        puts $MyNamespace::myVar
    }
}

MyNamespace::myProc  ;# 출력: 20
# ```

# ### 4. 정규화된 이름 생성

# 여러 네임스페이스를 거치는 경우, 이중 콜론으로 전체 경로를 지정할 수 있습니다.

# ```tcl
namespace eval Outer {
    namespace eval Inner {
        proc nestedProc {} {
            puts "Nested procedure"
        }
    }
}

::Outer::Inner::nestedProc  ;# 출력: Nested procedure
# ```

# ### 5. 변수 및 프로시저 이름 충돌 방지

# 이중 콜론을 사용하여 서로 다른 네임스페이스의 동일한 이름을 가진 변수나 프로시저를 구분할 수 있습니다.

# ```tcl
namespace eval NS1 {
    proc common {} {
        puts "NS1's common procedure"
    }
}

namespace eval NS2 {
    proc common {} {
        puts "NS2's common procedure"
    }
}

NS1::common  ;# 출력: NS1's common procedure
NS2::common  ;# 출력: NS2's common procedure
# ```

# ### 6. 현재 네임스페이스 참조

# 현재 네임스페이스를 명시적으로 참조할 때 사용할 수 있습니다.

# ```tcl
namespace eval MyNS {
    variable localVar 30
    
    proc accessVar {} {
        variable localVar
        puts ${::MyNS::localVar}  ;# 현재 네임스페이스의 변수 명시적 참조
    }
}

MyNS::accessVar  ;# 출력: 30
# ```

# ### 7. 이중 콜론과 upvar 사용

# 상위 스코프의 변수를 참조할 때 이중 콜론과 upvar를 함께 사용할 수 있습니다.

# ```tcl
proc outerProc {} {
    set localVar 40
    innerProc
}

proc innerProc {} {
    upvar 1 localVar globalVar
    puts $globalVar
}

outerProc  ;# 출력: 40

# ```

# ### 8. 주의사항 ⚠️

# * 과도한 이중 콜론 사용은 코드의 가독성을 떨어뜨릴 수 있습니다.
# * 네임스페이스를 사용할 때는 이름 충돌에 주의해야 합니다.
# * 전역 변수의 과다 사용은 코드의 모듈성을 해칠 수 있습니다.

# ### 9. 팁과 요령 💡

# * 가능한 지역 변수를 사용하고, 전역 변수 사용을 최소화하세요.
# * 네임스페이스를 사용하여 코드를 논리적으로 구조화하세요.
# * 변수나 프로시저의 스코프가 불분명할 때는 명시적으로 이중 콜론을 사용하세요.
# * 큰 프로젝트에서는 네임스페이스를 활용하여 모듈화된 구조를 만드세요.

# ### 10. 성능 고려사항 🚀

# * 이중 콜론을 사용한 전역 변수 접근은 지역 변수 접근보다 약간 더 느릴 수 있습니다.
# * 깊게 중첩된 네임스페이스를 자주 참조하면 성능에 영향을 줄 수 있습니다.

# TCL의 이중 콜론(::)을 마스터하여 효과적인 네임스페이스 관리와 변수 스코프 제어를 수행하세요!
