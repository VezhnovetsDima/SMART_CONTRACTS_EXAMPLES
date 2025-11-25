
// Простой прокси-контракт для реализации upgradeable pattern
contract SimpleProxy {
    // Адрес текущей реализации (логики контракта)
    // Хранится в слоте storage #0 - это важно для совместимости
    address public implementation;

    // Конструктор принимает адрес первоначальной реализации
    constructor(address _impl) {
        implementation = _impl;
    }

    // Функция для обновления реализации контракта
    // В реальном сценарии здесь должна быть проверка прав доступа
    function upgradeTo(address _newImpl) external {
        // Тут должна быть проверка прав (только владелец/админ), но опущена для простоты
        implementation = _newImpl;
    }

    // Fallback функция - вызывается когда вызывается несуществующая функция
    // или при отправке ether с пустыми данными
    fallback() external payable {
        // Получаем адрес текущей реализации
        address impl = implementation;
        
        // Ассемблерный блок для делегированного вызова
        assembly {
            // Копируем данные вызова (calldata) в память
            // calldatacopy(dest, offset, size)
            calldatacopy(0, 0, calldatasize())

            // Выполняем делегированный вызов к реализации
            // delegatecall(gas, address, argsOffset, argsSize, retOffset, retSize)
            let result := delegatecall(
                gas(),        // передаем весь доступный газ
                impl,         // адрес реализации
                0,            // аргументы начинаются с позиции 0 в памяти
                calldatasize(), // размер аргументов
                0,            // результат будет записан начиная с позиции 0
                0             // размер результата пока неизвестен
            )

            // Получаем размер возвращаемых данных
            let size := returndatasize()

            // Копируем возвращаемые данные в память
            // returndatacopy(dest, offset, size)
            returndatacopy(0, 0, size)

            // Обрабатываем результат вызова
            switch result
            case 0 {
                // Если вызов завершился неудачей (result = 0) - откатываем транзакцию
                revert(0, size)
            }
            default {
                // Если вызов успешен (result = 1) - возвращаем данные
                return(0, size)
            }
        }
    }

    // Receive функция - вызывается при получении Ether с пустыми данными
    receive() external payable {}
}

// Первая версия логики контракта
contract LogicV1 {
    // ВАЖНО: Структура хранения данных (storage layout) должна совпадать с прокси!
    address public implementation;  // слот #0 (такая же позиция как в прокси)
    uint256 public value;           // слот #1 (следующая переменная)

    // Событие для отслеживания изменений значения
    event ValueChanged(uint256 newValue);

    // Функция для установки значения
    function setValue(uint256 _v) external {
        value = _v;
        // Вызываем событие для записи в лог блокчейна
        emit ValueChanged(_v);
    }
}
