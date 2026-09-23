import 'dart:math';

/// 统一数据模型层：与数据库表结构一一对应

class Warehouse {
  int? id;
  String name;
  String? address;
  String? remark;
  int createTime;
  int updateTime;

  Warehouse({
    this.id,
    required this.name,
    this.address,
    this.remark,
    required this.createTime,
    required this.updateTime,
  });

  factory Warehouse.fromMap(Map<String, dynamic> m) => Warehouse(
        id: m['id'] as int?,
        name: (m['name'] ?? '') as String,
        address: m['address'] as String?,
        remark: m['remark'] as String?,
        createTime: (m['create_time'] ?? 0) as int,
        updateTime: (m['update_time'] ?? 0) as int,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'address': address,
        'remark': remark,
        'create_time': createTime,
        'update_time': updateTime,
      };
}

class Location {
  int? id;
  int warehouseId;
  String code;
  String name;
  int? parentId;
  String? remark;
  int createTime;

  Location({
    this.id,
    required this.warehouseId,
    required this.code,
    required this.name,
    this.parentId,
    this.remark,
    required this.createTime,
  });

  factory Location.fromMap(Map<String, dynamic> m) => Location(
        id: m['id'] as int?,
        warehouseId: m['warehouse_id'] as int,
        code: (m['code'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        parentId: m['parent_id'] as int?,
        remark: m['remark'] as String?,
        createTime: (m['create_time'] ?? 0) as int,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'warehouse_id': warehouseId,
        'code': code,
        'name': name,
        'parent_id': parentId,
        'remark': remark,
        'create_time': createTime,
      };
}

class Product {
  int? id;
  String? barcode;
  String name;
  String? spec;
  String? category;
  String unit;
  double costPrice;
  double salePrice;
  String? imagePath;
  double minStock;
  double maxStock;
  int warnDays;
  String? remark;
  int createTime;
  int updateTime;

  Product({
    this.id,
    this.barcode,
    required this.name,
    this.spec,
    this.category,
    required this.unit,
    this.costPrice = 0,
    this.salePrice = 0,
    this.imagePath,
    this.minStock = 0,
    this.maxStock = 0,
    this.warnDays = 30,
    this.remark,
    required this.createTime,
    required this.updateTime,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as int?,
        barcode: m['barcode'] as String?,
        name: (m['name'] ?? '') as String,
        spec: m['spec'] as String?,
        category: m['category'] as String?,
        unit: (m['unit'] ?? '件') as String,
        costPrice: _d(m['cost_price']),
        salePrice: _d(m['sale_price']),
        imagePath: m['image_path'] as String?,
        minStock: _d(m['min_stock']),
        maxStock: _d(m['max_stock']),
        warnDays: (m['warn_days'] ?? 30) as int,
        remark: m['remark'] as String?,
        createTime: (m['create_time'] ?? 0) as int,
        updateTime: (m['update_time'] ?? 0) as int,
      );

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'barcode': barcode,
        'name': name,
        'spec': spec,
        'category': category,
        'unit': unit,
        'cost_price': costPrice,
        'sale_price': salePrice,
        'image_path': imagePath,
        'min_stock': minStock,
        'max_stock': maxStock,
        'warn_days': warnDays,
        'remark': remark,
        'create_time': createTime,
        'update_time': updateTime,
      };

  /// 显示规格行
  String get specText => (spec == null || spec!.isEmpty) ? '规格：—' : '规格：$spec';
}

class Stock {
  int? id;
  int productId;
  int warehouseId;
  int? locationId;
  String? batchNo;
  int? produceDate;
  int? expireDate;
  double quantity;
  int createTime;
  int updateTime;

  Stock({
    this.id,
    required this.productId,
    required this.warehouseId,
    this.locationId,
    this.batchNo,
    this.produceDate,
    this.expireDate,
    required this.quantity,
    required this.createTime,
    required this.updateTime,
  });

  factory Stock.fromMap(Map<String, dynamic> m) => Stock(
        id: m['id'] as int?,
        productId: m['product_id'] as int,
        warehouseId: m['warehouse_id'] as int,
        locationId: m['location_id'] as int?,
        batchNo: m['batch_no'] as String?,
        produceDate: m['produce_date'] as int?,
        expireDate: m['expire_date'] as int?,
        quantity: (m['quantity'] ?? 0) is num ? (m['quantity'] as num).toDouble() : 0,
        createTime: (m['create_time'] ?? 0) as int,
        updateTime: (m['update_time'] ?? 0) as int,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'warehouse_id': warehouseId,
        'location_id': locationId,
        'batch_no': batchNo,
        'produce_date': produceDate,
        'expire_date': expireDate,
        'quantity': quantity,
        'create_time': createTime,
        'update_time': updateTime,
      };
}

/// 库存行展示视图：库存+商品+仓库聚合
class StockRow {
  final Stock stock;
  final Product product;
  final String warehouseName;
  final double amount;
  StockRow(this.stock, this.product, this.warehouseName, this.amount);
}

// ---------------- 入库 ----------------

class StockInOrder {
  static const typeNames = {1: '采购入库', 2: '销售退货入库', 3: '盘盈入库', 4: '其他入库'};
  static const statusNames = {0: '草稿', 1: '已确认', 2: '已作废'};

  int? id;
  String orderNo;
  int orderType;
  int warehouseId;
  String? supplier;
  double totalNum;
  double totalAmount;
  String? imagePaths;
  String? remark;
  int status;
  int createTime;
  int? confirmTime;
  List<StockInItem> items;
  String? warehouseName;

  StockInOrder({
    this.id,
    required this.orderNo,
    this.orderType = 1,
    required this.warehouseId,
    this.supplier,
    this.totalNum = 0,
    this.totalAmount = 0,
    this.imagePaths,
    this.remark,
    this.status = 0,
    required this.createTime,
    this.confirmTime,
    List<StockInItem>? items,
    this.warehouseName,
  }) : items = items ?? [];

  factory StockInOrder.fromMap(Map<String, dynamic> m) => StockInOrder(
        id: m['id'] as int?,
        orderNo: (m['order_no'] ?? '') as String,
        orderType: (m['order_type'] ?? 1) as int,
        warehouseId: m['warehouse_id'] as int,
        supplier: m['supplier'] as String?,
        totalNum: _d(m['total_num']),
        totalAmount: _d(m['total_amount']),
        imagePaths: m['image_paths'] as String?,
        remark: m['remark'] as String?,
        status: (m['status'] ?? 0) as int,
        createTime: (m['create_time'] ?? 0) as int,
        confirmTime: m['confirm_time'] as int?,
        warehouseName: m['warehouse_name'] as String?,
      );

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_no': orderNo,
        'order_type': orderType,
        'warehouse_id': warehouseId,
        'supplier': supplier,
        'total_num': totalNum,
        'total_amount': totalAmount,
        'image_paths': imagePaths,
        'remark': remark,
        'status': status,
        'create_time': createTime,
        'confirm_time': confirmTime,
      };

  String get typeName => typeNames[orderType] ?? '入库';
  String get statusName => statusNames[status] ?? '';
}

class StockInItem {
  int? id;
  int? orderId;
  int productId;
  int? locationId;
  String? batchNo;
  int? produceDate;
  int? expireDate;
  double quantity;
  double price;
  double amount;
  String? remark;
  Product? product;

  StockInItem({
    this.id,
    this.orderId,
    required this.productId,
    this.locationId,
    this.batchNo,
    this.produceDate,
    this.expireDate,
    required this.quantity,
    this.price = 0,
    this.amount = 0,
    this.remark,
    this.product,
  });

  factory StockInItem.fromMap(Map<String, dynamic> m) => StockInItem(
        id: m['id'] as int?,
        orderId: m['order_id'] as int?,
        productId: m['product_id'] as int,
        locationId: m['location_id'] as int?,
        batchNo: m['batch_no'] as String?,
        produceDate: m['produce_date'] as int?,
        expireDate: m['expire_date'] as int?,
        quantity: _d(m['quantity']),
        price: _d(m['price']),
        amount: _d(m['amount']),
        remark: m['remark'] as String?,
      );

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'product_id': productId,
        'location_id': locationId,
        'batch_no': batchNo,
        'produce_date': produceDate,
        'expire_date': expireDate,
        'quantity': quantity,
        'price': price,
        'amount': amount,
        'remark': remark,
      };
}

// ---------------- 出库 ----------------

class StockOutOrder {
  static const typeNames = {1: '销售出库', 2: '采购退货出库', 3: '生产领料', 4: '盘亏出库', 5: '其他出库'};
  static const statusNames = {0: '草稿', 1: '已确认', 2: '已作废'};

  int? id;
  String orderNo;
  int orderType;
  int warehouseId;
  String? customer;
  double totalNum;
  double totalAmount;
  String? imagePaths;
  String? remark;
  int status;
  int createTime;
  int? confirmTime;
  List<StockOutItem> items;
  String? warehouseName;

  StockOutOrder({
    this.id,
    required this.orderNo,
    this.orderType = 1,
    required this.warehouseId,
    this.customer,
    this.totalNum = 0,
    this.totalAmount = 0,
    this.imagePaths,
    this.remark,
    this.status = 0,
    required this.createTime,
    this.confirmTime,
    List<StockOutItem>? items,
    this.warehouseName,
  }) : items = items ?? [];

  factory StockOutOrder.fromMap(Map<String, dynamic> m) => StockOutOrder(
        id: m['id'] as int?,
        orderNo: (m['order_no'] ?? '') as String,
        orderType: (m['order_type'] ?? 1) as int,
        warehouseId: m['warehouse_id'] as int,
        customer: m['customer'] as String?,
        totalNum: _d(m['total_num']),
        totalAmount: _d(m['total_amount']),
        imagePaths: m['image_paths'] as String?,
        remark: m['remark'] as String?,
        status: (m['status'] ?? 0) as int,
        createTime: (m['create_time'] ?? 0) as int,
        confirmTime: m['confirm_time'] as int?,
        warehouseName: m['warehouse_name'] as String?,
      );

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_no': orderNo,
        'order_type': orderType,
        'warehouse_id': warehouseId,
        'customer': customer,
        'total_num': totalNum,
        'total_amount': totalAmount,
        'image_paths': imagePaths,
        'remark': remark,
        'status': status,
        'create_time': createTime,
        'confirm_time': confirmTime,
      };

  String get typeName => typeNames[orderType] ?? '出库';
  String get statusName => statusNames[status] ?? '';
}

class StockOutItem {
  int? id;
  int? orderId;
  int productId;
  int? locationId;
  String? batchNo;
  double quantity;
  double price;
  double amount;
  String? remark;
  Product? product;

  StockOutItem({
    this.id,
    this.orderId,
    required this.productId,
    this.locationId,
    this.batchNo,
    required this.quantity,
    this.price = 0,
    this.amount = 0,
    this.remark,
    this.product,
  });

  factory StockOutItem.fromMap(Map<String, dynamic> m) => StockOutItem(
        id: m['id'] as int?,
        orderId: m['order_id'] as int?,
        productId: m['product_id'] as int,
        locationId: m['location_id'] as int?,
        batchNo: m['batch_no'] as String?,
        quantity: _d(m['quantity']),
        price: _d(m['price']),
        amount: _d(m['amount']),
        remark: m['remark'] as String?,
      );

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'product_id': productId,
        'location_id': locationId,
        'batch_no': batchNo,
        'quantity': quantity,
        'price': price,
        'amount': amount,
        'remark': remark,
      };
}

// ---------------- 调拨 ----------------

class TransferOrder {
  static const statusNames = {0: '草稿', 1: '已调出', 2: '已调入', 3: '已作废'};

  int? id;
  String orderNo;
  int outWarehouseId;
  int inWarehouseId;
  double totalNum;
  int status;
  String? remark;
  int createTime;
  int? outTime;
  int? inTime;
  int stepMode; // 1一步调拨 2两步调拨
  List<TransferItem> items;
  String? outWarehouseName;
  String? inWarehouseName;

  TransferOrder({
    this.id,
    required this.orderNo,
    required this.outWarehouseId,
    required this.inWarehouseId,
    this.totalNum = 0,
    this.status = 0,
    this.remark,
    required this.createTime,
    this.outTime,
    this.inTime,
    this.stepMode = 1,
    List<TransferItem>? items,
    this.outWarehouseName,
    this.inWarehouseName,
  }) : items = items ?? [];

  factory TransferOrder.fromMap(Map<String, dynamic> m) => TransferOrder(
        id: m['id'] as int?,
        orderNo: (m['order_no'] ?? '') as String,
        outWarehouseId: m['out_warehouse_id'] as int,
        inWarehouseId: m['in_warehouse_id'] as int,
        totalNum: _d(m['total_num']),
        status: (m['status'] ?? 0) as int,
        remark: m['remark'] as String?,
        createTime: (m['create_time'] ?? 0) as int,
        outTime: m['out_time'] as int?,
        inTime: m['in_time'] as int?,
        stepMode: (m['step_mode'] ?? 1) as int,
        outWarehouseName: m['out_wh_name'] as String?,
        inWarehouseName: m['in_wh_name'] as String?,
      );

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_no': orderNo,
        'out_warehouse_id': outWarehouseId,
        'in_warehouse_id': inWarehouseId,
        'total_num': totalNum,
        'status': status,
        'remark': remark,
        'create_time': createTime,
        'out_time': outTime,
        'in_time': inTime,
        'step_mode': stepMode,
      };

  String get statusName => statusNames[status] ?? '';
}

class TransferItem {
  int? id;
  int? orderId;
  int productId;
  String? batchNo;
  double quantity;
  int? outLocationId;
  int? inLocationId;
  String? remark;
  Product? product;

  TransferItem({
    this.id,
    this.orderId,
    required this.productId,
    this.batchNo,
    required this.quantity,
    this.outLocationId,
    this.inLocationId,
    this.remark,
    this.product,
  });

  factory TransferItem.fromMap(Map<String, dynamic> m) => TransferItem(
        id: m['id'] as int?,
        orderId: m['order_id'] as int?,
        productId: m['product_id'] as int,
        batchNo: m['batch_no'] as String?,
        quantity: _d(m['quantity']),
        outLocationId: m['out_location_id'] as int?,
        inLocationId: m['in_location_id'] as int?,
        remark: m['remark'] as String?,
      );

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'product_id': productId,
        'batch_no': batchNo,
        'quantity': quantity,
        'out_location_id': outLocationId,
        'in_location_id': inLocationId,
        'remark': remark,
      };
}

// ---------------- 盘点 ----------------

class CheckOrder {
  static const rangeNames = {1: '全盘', 2: '按货位', 3: '按分类'};
  static const statusNames = {0: '进行中', 1: '已完成', 2: '已作废'};

  int? id;
  String orderNo;
  int warehouseId;
  int checkRange;
  String? rangeParam;
  int totalSku;
  int diffSku;
  int status;
  String? remark;
  int createTime;
  int? finishTime;
  String? warehouseName;
  List<CheckItem> items;

  CheckOrder({
    this.id,
    required this.orderNo,
    required this.warehouseId,
    this.checkRange = 1,
    this.rangeParam,
    this.totalSku = 0,
    this.diffSku = 0,
    this.status = 0,
    this.remark,
    required this.createTime,
    this.finishTime,
    this.warehouseName,
    this.items = const [],
  });

  factory CheckOrder.fromMap(Map<String, dynamic> m) => CheckOrder(
        id: m['id'] as int?,
        orderNo: (m['order_no'] ?? '') as String,
        warehouseId: m['warehouse_id'] as int,
        checkRange: (m['check_range'] ?? 1) as int,
        rangeParam: m['range_param'] as String?,
        totalSku: (m['total_sku'] ?? 0) as int,
        diffSku: (m['diff_sku'] ?? 0) as int,
        status: (m['status'] ?? 0) as int,
        remark: m['remark'] as String?,
        createTime: (m['create_time'] ?? 0) as int,
        finishTime: m['finish_time'] as int?,
        warehouseName: m['warehouse_name'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_no': orderNo,
        'warehouse_id': warehouseId,
        'check_range': checkRange,
        'range_param': rangeParam,
        'total_sku': totalSku,
        'diff_sku': diffSku,
        'status': status,
        'remark': remark,
        'create_time': createTime,
        'finish_time': finishTime,
      };

  String get rangeName => rangeNames[checkRange] ?? '全盘';
  String get statusName => statusNames[status] ?? '';
}

class CheckItem {
  int? id;
  int orderId;
  int productId;
  int? locationId;
  String? batchNo;
  double bookQuantity;
  double? actualQuantity;
  double? diffQuantity;
  String? diffReason;
  String? remark;
  Product? product;

  CheckItem({
    required this.orderId,
    required this.productId,
    this.locationId,
    this.batchNo,
    required this.bookQuantity,
    this.actualQuantity,
    this.diffQuantity,
    this.diffReason,
    this.remark,
    this.product,
    this.id,
  });

  factory CheckItem.fromMap(Map<String, dynamic> m) => CheckItem(
        id: m['id'] as int?,
        orderId: m['order_id'] as int,
        productId: m['product_id'] as int,
        locationId: m['location_id'] as int?,
        batchNo: m['batch_no'] as String?,
        bookQuantity: _d(m['book_quantity']),
        actualQuantity: _dn(m['actual_quantity']),
        diffQuantity: _dn(m['diff_quantity']),
        diffReason: m['diff_reason'] as String?,
        remark: m['remark'] as String?,
      );

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
  static double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'product_id': productId,
        'location_id': locationId,
        'batch_no': batchNo,
        'book_quantity': bookQuantity,
        'actual_quantity': actualQuantity,
        'diff_quantity': diffQuantity,
        'diff_reason': diffReason,
        'remark': remark,
      };
}

// ---------------- 预警 ----------------

class AlertInfo {
  static const typeInsufficient = 'insufficient';
  static const typeOver = 'over';
  static const typeExpiring = 'expiring';
  static const typeExpired = 'expired';
  static const typeNames = {
    typeInsufficient: '不足',
    typeOver: '积压',
    typeExpiring: '临期',
    typeExpired: '过期',
  };

  final Product product;
  final String type;
  final double stock;
  final double? limitValue;
  final int? remainDays;
  final int? overdueDays;

  AlertInfo({
    required this.product,
    required this.type,
    required this.stock,
    this.limitValue,
    this.remainDays,
    this.overdueDays,
  });

  String get typeName => typeNames[type]!;
}

/// 首页统计
class HomeStats {
  double totalValue;
  double totalValueDelta;
  double todayInNum;
  double todayInDelta;
  double todayOutNum;
  double todayOutDelta;
  int alertCount;
  double alertDelta;

  HomeStats({
    this.totalValue = 0,
    this.totalValueDelta = 0,
    this.todayInNum = 0,
    this.todayInDelta = 0,
    this.todayOutNum = 0,
    this.todayOutDelta = 0,
    this.alertCount = 0,
    this.alertDelta = 0,
  });

  static double pct(double cur, double base) {
    if (base <= 0) return 0;
    return (cur - base) / base * 100;
  }

  static String fmtPct(double v) => '${v >= 0 ? '↑' : '↓'} ${v.abs().toStringAsFixed(1)}%';
}

/// 工具：数量显示（去掉多余小数）
String fmtQty(double v) {
  final r = v.roundToDouble();
  if ((v - r).abs() < 1e-9) {
    final f = NumberFormatDec();
    return f.intFmt(r);
  }
  return NumberFormatDec().decFmt(v);
}

/// 轻量数字格式化（避免到处依赖 intl 实例）
class NumberFormatDec {
  String intFmt(double v) {
    final i = v.truncate();
    final s = i.abs().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return v < 0 ? '-$s' : s;
  }

  String decFmt(double v) {
    final fixed = v.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '${v < 0 ? '-' : ''}$intPart.${parts[1]}';
  }
}

double round2(double v) {
  final f = pow(10, 2).toDouble();
  return (v * f).roundToDouble() / f;
}
