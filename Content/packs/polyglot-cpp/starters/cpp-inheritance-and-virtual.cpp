#include <string>
#include <stdexcept>

class Employee {
public:
    Employee(const std::string& name, int salary) : name_(name), salary_(salary) {}
    virtual ~Employee() = default;
    virtual int bonus() const {
        return 0;
    }
    std::string name() const { return name_; }
    int salary() const { return salary_; }
protected:
    std::string name_;
    int salary_;
};

class Manager : public Employee {
public:
    Manager(const std::string& name, int salary) : Employee(name, salary) {}
    int bonus() const override {
        // salary 의 10% 를 정수로 돌려준다 (소수점 이하는 버린다).
        throw std::runtime_error("여기를 구현해라");
    }
};

class Intern : public Employee {
public:
    Intern(const std::string& name, int salary) : Employee(name, salary) {}
    int bonus() const override {
        // salary 와 무관하게 항상 50000 을 돌려준다.
        throw std::runtime_error("여기를 구현해라");
    }
};
