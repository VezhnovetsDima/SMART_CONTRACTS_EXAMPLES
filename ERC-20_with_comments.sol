// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleERC20 {
    // === ОБЪЯВЛЕНИЕ ПЕРЕМЕННЫХ ===
    
    // Напоминаю: public означает что автоматически генерируется get функция для переменной
    // Название токена (например, "My Token")
    string public name;
    
    // Символ токена (например, "MTK" - тикер)
    string public symbol;
    
    // Количество знаков после запятой (как копейки у рубля)
    // 18 - стандартное значение, как у ETH (1 токен = 10^18 единиц)
    uint8 public decimals;
    
    // Общее количество выпущенных токенов
    uint256 public totalSupply;
    
    // Маппинг (словарь) для хранения балансов пользователей
    // Ключ: адрес, Значение: количество токенов
    mapping(address => uint256) public balanceOf;
    
    // Маппинг для хранения разрешений (allowance)
    // allowance[владелец][доверенное_лицо] = количество_токенов
    // Позволяет доверенному лицу тратить токены от имени владельца
    mapping(address => mapping(address => uint256)) public allowance;
    
    // === СОБЫТИЯ (EVENTS) ===
    
    // Событие перевода токенов
    // Вызывается при ЛЮБОЙ успешной передаче токенов
    // indexed - позволяет эффективно фильтровать события по этим полям
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    // Событие выдачи разрешения
    // Вызывается при успешном вызове функции approve
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // === КОНСТРУКТОР ===
    // Вызывается ОДИН раз при деплое контракта
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) {
        // Устанавливаем основные параметры токена
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        
        // Рассчитываем реальное количество токенов с учётом decimals
        // Например: если _initialSupply = 1000 и decimals = 18,
        // то supply = 1000 * 10^18 = 1000 полноценных токенов
        uint256 supply = _initialSupply * (10 ** _decimals);
        totalSupply = supply;
        balanceOf[msg.sender] = supply;
        
        // Эмитим событие Transfer для обозначения создания токенов
        // from = address(0) - означает "создание из ниоткуда" (mint)
        // to = msg.sender - получатель (создатель контракта)
        emit Transfer(address(0), msg.sender, supply);
    }
    
    // === ОСНОВНЫЕ ФУНКЦИИ ===
    
    // Функция ПРЯМОГО перевода токенов
    // Вызывается владельцем токенов для перевода кому-то другому
    function transfer(address to, uint256 value) external returns (bool) {
        // ПРОВЕРКА 1: У отправителя достаточно токенов
        require(balanceOf[msg.sender] >= value, "Insufficient");
        
        // ПРОВЕРКА 2: Получатель не нулевой адрес
        // (обычно перевод на address(0) считается сжиганием)
        require(to != address(0), "Zero address");
        
        // ВЫПОЛНЕНИЕ ПЕРЕВОДА:
        // Уменьшаем баланс отправителя
        balanceOf[msg.sender] -= value;
        
        // Увеличиваем баланс получателя
        balanceOf[to] += value;
        
        // Эмитим событие о переводе
        emit Transfer(msg.sender, to, value);
        
        // Возвращаем true при успешном выполнении
        return true;
    }
    
    // Функция ВЫДАЧИ РАЗРЕШЕНИЯ другому адресу
    // Позволяет spender тратить ваши токены в пределах value
    function approve(address spender, uint256 value) external returns (bool) {
        // Устанавливаем разрешение:
        // "spender может потратить до value токенов от моего имени"
        allowance[msg.sender][spender] = value;
        
        // Создаем событие о выдаче разрешения
        emit Approval(msg.sender, spender, value);
        
        return true;
    }
    
    // Функция перевода токенов ПО ДОВЕРЕННОСТИ
    // Вызывается доверенным лицом (spender) для перевода токенов от владельца
    function transferFrom(
        address from,      // Владелец токенов
        address to,        // Получатель
        uint256 value      // Количество токенов
    ) external returns (bool) {
        // ПРОВЕРКА 1: У владельца достаточно токенов
        require(balanceOf[from] >= value, "Insufficient");
        
        // ПРОВЕРКА 2: У вызывающего (msg.sender) достаточно разрешения
        require(allowance[from][msg.sender] >= value, "No allowance");
        
        // ПРОВЕРКА 3: Получатель не нулевой адрес
        require(to != address(0), "Zero address");
        
        // ВЫПОЛНЕНИЕ ОПЕРАЦИИ:
        
        // 1. Уменьшаем разрешение (сколько ещё можно потратить)
        allowance[from][msg.sender] -= value;
        
        // 2. Уменьшаем баланс владельца
        balanceOf[from] -= value;
        
        // 3. Увеличиваем баланс получателя
        balanceOf[to] += value;
        
        // Эмитим событие о переводе
        emit Transfer(from, to, value);
        
        return true;
    }
}