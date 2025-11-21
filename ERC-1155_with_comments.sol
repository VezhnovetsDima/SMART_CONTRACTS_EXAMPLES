// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Импорты необходимых интерфейсов и библиотек
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title ERC1155 - Полная реализация мультитокен стандарта
 * @dev Реализация всех обязательных функций ERC-1155
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address; // Используем библиотеку Address для проверок

    // Хранилище балансов: mapping(id => mapping(account => balance))
    mapping(uint256 => mapping(address => uint256)) private _balances;
    
    // Хранилище разрешений операторов: mapping(owner => mapping(operator => approved))
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    // Базовый URI для метаданных токенов
    string private _uri;

    /**
     * @dev Конструктор устанавливает базовый URI
     * @param uri_ Базовый URI для метаданных токенов
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev Реализация ERC-165 для проверки поддерживаемых интерфейсов
     * @param interfaceId ID интерфейса для проверки
     * @return bool Поддерживается ли интерфейс
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId || // Проверка основного интерфейса ERC-1155
            interfaceId == type(IERC1155MetadataURI).interfaceId || // Проверка интерфейса метаданных
            super.supportsInterface(interfaceId); // Проверка родительских интерфейсов
    }

    /**
     * @dev Возвращает URI для конкретного токена
     * @param id ID токена
     * @return string URI токена
     */
    function uri(uint256 id) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev Возвращает баланс конкретного токена у аккаунта
     * @param account Адрес аккаунта
     * @param id ID токена
     * @return uint256 Баланс токена
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }

    /**
     * @dev Пакетное получение балансов для нескольких аккаунтов и токенов
     * @param accounts Массив адресов аккаунтов
     * @param ids Массив ID токенов
     * @return uint256[] Массив балансов
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        // Проверка корректности входных данных
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        // Создание массива для результатов
        uint256[] memory batchBalances = new uint256[](accounts.length);

        // Заполнение массива балансами
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev Установка/снятие разрешения для оператора управлять всеми токенами
     * @param operator Адрес оператора
     * @param approved Разрешить или запретить
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev Проверка разрешений оператора
     * @param account Владелец токенов
     * @param operator Оператор
     * @return bool Имеет ли оператор разрешение
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev Безопасная передача одного токена
     * @param from Отправитель
     * @param to Получатель
     * @param id ID токена
     * @param amount Количество
     * @param data Дополнительные данные
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        // Проверка прав отправителя
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev Безопасная пакетная передача токенов
     * @param from Отправитель
     * @param to Получатель
     * @param ids Массив ID токенов
     * @param amounts Массив количеств
     * @param data Дополнительные данные
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        // Проверка прав отправителя
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    // ========================= ВНУТРЕННИЕ ФУНКЦИИ =========================

    /**
     * @dev Внутренняя функция безопасной передачи одного токена
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        // Проверка валидности получателя
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();
        
        // Преобразование в массивы для совместимости с хуками
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        // Вызов хука перед передачей
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        // Обновление балансов
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount; // Безопасное вычитание
        }
        _balances[id][to] += amount;

        // Эмиссия события
        emit TransferSingle(operator, from, to, id, amount);

        // Вызов хука после передачи
        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        // Проверка получения контрактом-получателем
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev Внутренняя функция безопасной пакетной передачи
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        // Проверки входных данных
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        // Хук перед передачей
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        // Обновление балансов для всех токенов
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        // Эмиссия события пакетной передачи
        emit TransferBatch(operator, from, to, ids, amounts);

        // Хук после передачи
        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        // Проверка получения контрактом-получателем
        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Установка базового URI
     * @param newuri Новый URI
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Минтинг (создание) одного токена
     * @param to Получатель
     * @param id ID токена
     * @param amount Количество
     * @param data Дополнительные данные
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        // Хук перед минтом
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        // Увеличение баланса получателя
        _balances[id][to] += amount;
        
        // Эмиссия события
        emit TransferSingle(operator, address(0), to, id, amount);

        // Хук после минта
        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        // Проверка получения
        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev Пакетный минт токенов
     * @param to Получатель
     * @param ids Массив ID токенов
     * @param amounts Массив количеств
     * @param data Дополнительные данные
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        // Хук перед минтом
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        // Увеличение балансов для всех токенов
        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        // Эмиссия события пакетного минта
        emit TransferBatch(operator, address(0), to, ids, amounts);

        // Хук после минта
        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        // Проверка получения
        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Сжигание (уничтожение) одного токена
     * @param from Владелец
     * @param id ID токена
     * @param amount Количество
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        // Хук перед сжиганием
        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        // Уменьшение баланса
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        // Эмиссия события
        emit TransferSingle(operator, from, address(0), id, amount);

        // Хук после сжигания
        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev Пакетное сжигание токенов
     * @param from Владелец
     * @param ids Массив ID токенов
     * @param amounts Массив количеств
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        // Хук перед сжиганием
        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        // Уменьшение балансов для всех токенов
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        // Эмиссия события пакетного сжигания
        emit TransferBatch(operator, from, address(0), ids, amounts);

        // Хук после сжигания
        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev Внутренняя установка разрешений оператора
     * @param owner Владелец
     * @param operator Оператор
     * @param approved Разрешить или запретить
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    // ========================= ХУКИ =========================

    /**
     * @dev Хук, вызываемый перед любой передачей токенов
     * Может быть переопределен в дочерних контрактах
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    /**
     * @dev Хук, вызываемый после любой передачи токенов
     * Может быть переопределен в дочерних контрактах
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    // ========================= ПРОВЕРКИ БЕЗОПАСНОСТИ =========================

    /**
     * @dev Проверка безопасного получения одного токена
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        // Проверяем, является ли получатель контрактом
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                // Проверяем, что контракт вернул правильный селектор
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    /**
     * @dev Проверка безопасного пакетного получения токенов
     */
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        // Проверяем, является ли получатель контрактом
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                // Проверяем, что контракт вернул правильный селектор
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    /**
     * @dev Вспомогательная функция для создания массива из одного элемента
     * @param element Элемент для помещения в массив
     * @return uint256[] Массив с одним элементом
     */
    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }
}