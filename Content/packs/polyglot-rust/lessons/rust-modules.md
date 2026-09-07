@Concept(id: rust-modules-concept) {
파일 하나에 struct 와 함수가 계속 늘어나면 관련된 것들을 눈으로 구분하기 어려워진다. `mod 이름 { ... }` 은 코드를 하나의 이름 아래 묶어 그 문제를 해결한다. 묶인 코드는 `이름::항목` 형태의 **경로**로 바깥에서 찾아갈 수 있다 — 마치 파일 시스템에서 폴더를 거쳐 파일을 찾듯이.

모듈 안의 항목은 기본이 **비공개**다. 아무 표시가 없으면 그 모듈 밖에서는 보이지 않는다. 바깥에 공개하려면 `pub` 을 붙여야 한다 — struct 앞에 붙이면 그 타입 자체가 보이고, struct 필드 앞에 붙이면 그 필드까지 보인다. `struct` 에는 `pub` 을 붙였는데 필드에는 안 붙이면, 타입 이름은 알 수 있어도 `Circle { radius: 1.0 }` 처럼 직접 만들 수는 없다 — 필드가 여전히 감춰져 있기 때문이다. 이 기본값 덕분에 모듈은 내부 구현을 숨기고 정말 필요한 것만 드러낼 수 있다.

경로를 매번 전부 쓰는 것은 번거롭다. `shapes::Circle` 을 여러 번 쓰는 대신 `use shapes::Circle;` 을 한 번 적어 두면 그 뒤로는 `Circle` 만으로 충분하다. `use` 는 새로운 것을 만드는 게 아니라 이미 있는 경로를 짧은 이름으로 그 자리에서 쓸 수 있게 끌어오는 것뿐이다 — 원래의 전체 경로로 써도 여전히 동작한다.

결국 `mod` 는 코드를 나누고, `pub` 은 그중 무엇을 보여줄지 고르고, `use` 는 그렇게 나눈 것을 편하게 부르는 세 가지 역할을 나눠 맡는다.
}

@Example(id: rust-modules-example, language: rust, expected: expected/rust-modules.txt) {
`geometry` 모듈 안의 `Rectangle` 과 `describe` 는 `pub` 이 붙어 바깥에서 보인다. `use` 로 가져온 뒤에는 짧은 이름으로, 가져오지 않아도 전체 경로로 똑같이 쓸 수 있다.

```rust
mod geometry {
    pub struct Rectangle {
        pub width: f64,
        pub height: f64,
    }

    impl Rectangle {
        pub fn area(&self) -> f64 {
            self.width * self.height
        }
    }

    pub fn describe(r: &Rectangle) -> String {
        format!("넓이 {:.1}", r.area())
    }
}

use geometry::{Rectangle, describe};

fn main() {
    let r = Rectangle { width: 3.0, height: 4.0 };
    println!("{}", describe(&r));
    println!("{}", geometry::describe(&r));
}
```
}

@Blank(id: rust-modules-blank, language: rust) {
모듈을 선언하는 키워드, struct 와 메서드를 공개하는 키워드, 짧은 이름으로 가져오는 키워드를 채워라.

```rust
___1___ shapes {
    ___2___ struct Circle {
        pub radius: f64,
    }

    impl Circle {
        ___3___ fn area(&self) -> f64 {
            3.14 * self.radius * self.radius
        }
    }
}

___4___ shapes::Circle;

fn main() {
    let c = Circle { radius: 2.0 };
    println!("{:.2}", c.area());
}
```

@Answer(slot: 1) {
`mod`
}

@Answer(slot: 2) {
`pub`
}

@Answer(slot: 3) {
`pub`
}

@Answer(slot: 4) {
`use`
}
}

@Task(id: rust-modules-task, language: rust, starter: starters/rust-modules.rs, tests: tests/rust-modules.rs, solution: solutions/rust-modules.rs) {
`stats` 모듈 안의 `average` 함수를 완성하라. 이미 구현된 `total` 함수를 활용해 합을 구하고 `nums.len()` 으로 나눈 평균을 돌려준다. 목록이 비어 있으면 `0.0` 을 돌려준다.

@Hint {
`nums.is_empty()` 로 빈 목록을 먼저 걸러내라.
}

@Hint {
합은 이미 있는 `total(nums)` 를 그대로 불러 쓰면 된다 — 다시 구현할 필요가 없다.
}

@Hint {
나눗셈 전에 `total(nums) as f64` 와 `nums.len() as f64` 로 각각 형변환하라.
}
}

@Quiz(id: rust-modules-quiz, answer: module-private) {
@Question {
모듈 안의 struct 필드에 `pub` 을 붙이지 않으면 어떻게 되나요?
}

@Choice(id: module-private) {
같은 모듈 안에서는 접근할 수 있지만, 모듈 바깥에서는 접근할 수 없다
}

@Choice(id: never-accessible) {
어디서도 접근할 수 없어 그 필드가 있는 코드는 항상 컴파일에 실패한다
}

@Choice(id: mut-only) {
가변 참조를 통해서만 접근할 수 있게 된다
}

@Choice(id: cannot-declare) {
pub 없이는 애초에 필드를 선언할 수 없다
}

@Explanation {
러스트의 기본 공개 범위는 "모듈 안에서는 보이고, 밖에서는 안 보이는" 것이다. 그래서 `impl` 블록처럼 같은 모듈 안의 코드는 `pub` 없는 필드도 그대로 쓸 수 있지만, 모듈 밖에서 `Circle { radius: 1.0 }` 처럼 직접 만들려면 `pub` 이 필요하다. 컴파일이 항상 실패하는 것도, 가변 참조만 허용되는 것도 아니고, pub 없이도 필드 선언 자체는 문제없다.
}
}

@Reflection(id: rust-modules-reflection) {
@Prompt(id: why-group-with-mod) {
지금까지 만들어 본 코드 중 하나를 떠올려, `mod` 로 관련된 struct 와 함수를 묶는다면 어떻게 나누고 싶은지 적어 보세요.
}

@Prompt(id: use-convenience) {
`use geometry::describe;` 없이 매번 `geometry::describe(...)` 라고만 써야 했다면 무엇이 불편했을지 생각해 보세요.
}
}
