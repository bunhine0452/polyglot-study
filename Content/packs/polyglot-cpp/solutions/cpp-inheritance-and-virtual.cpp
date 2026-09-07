#include <string>

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
        return salary_ / 10;
    }
};

class Intern : public Employee {
public:
    Intern(const std::string& name, int salary) : Employee(name, salary) {}
    int bonus() const override {
        return 50000;
    }
};
