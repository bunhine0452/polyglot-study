#include <sstream>
#include <iomanip>
#include <string>

std::string formatFixed(double value) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(2) << value;
    return out.str();
}
