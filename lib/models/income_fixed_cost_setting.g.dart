// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'income_fixed_cost_setting.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIncomeFixedCostSettingCollection on Isar {
  IsarCollection<IncomeFixedCostSetting> get incomeFixedCostSettings =>
      this.collection();
}

const IncomeFixedCostSettingSchema = CollectionSchema(
  name: r'IncomeFixedCostSetting',
  id: -3545849776681966953,
  properties: {
    r'fixedCostTotal': PropertySchema(
      id: 0,
      name: r'fixedCostTotal',
      type: IsarType.long,
    ),
    r'income': PropertySchema(
      id: 1,
      name: r'income',
      type: IsarType.long,
    ),
    r'items': PropertySchema(
      id: 2,
      name: r'items',
      type: IsarType.objectList,
      target: r'IncomeFixedCostItem',
    ),
    r'updatedAt': PropertySchema(
      id: 3,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _incomeFixedCostSettingEstimateSize,
  serialize: _incomeFixedCostSettingSerialize,
  deserialize: _incomeFixedCostSettingDeserialize,
  deserializeProp: _incomeFixedCostSettingDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {r'IncomeFixedCostItem': IncomeFixedCostItemSchema},
  getId: _incomeFixedCostSettingGetId,
  getLinks: _incomeFixedCostSettingGetLinks,
  attach: _incomeFixedCostSettingAttach,
  version: '3.1.0+1',
);

int _incomeFixedCostSettingEstimateSize(
  IncomeFixedCostSetting object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.items.length * 3;
  {
    final offsets = allOffsets[IncomeFixedCostItem]!;
    for (var i = 0; i < object.items.length; i++) {
      final value = object.items[i];
      bytesCount +=
          IncomeFixedCostItemSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  return bytesCount;
}

void _incomeFixedCostSettingSerialize(
  IncomeFixedCostSetting object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.fixedCostTotal);
  writer.writeLong(offsets[1], object.income);
  writer.writeObjectList<IncomeFixedCostItem>(
    offsets[2],
    allOffsets,
    IncomeFixedCostItemSchema.serialize,
    object.items,
  );
  writer.writeDateTime(offsets[3], object.updatedAt);
}

IncomeFixedCostSetting _incomeFixedCostSettingDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IncomeFixedCostSetting();
  object.fixedCostTotal = reader.readLong(offsets[0]);
  object.id = id;
  object.income = reader.readLong(offsets[1]);
  object.items = reader.readObjectList<IncomeFixedCostItem>(
        offsets[2],
        IncomeFixedCostItemSchema.deserialize,
        allOffsets,
        IncomeFixedCostItem(),
      ) ??
      [];
  object.updatedAt = reader.readDateTime(offsets[3]);
  return object;
}

P _incomeFixedCostSettingDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readObjectList<IncomeFixedCostItem>(
            offset,
            IncomeFixedCostItemSchema.deserialize,
            allOffsets,
            IncomeFixedCostItem(),
          ) ??
          []) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _incomeFixedCostSettingGetId(IncomeFixedCostSetting object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _incomeFixedCostSettingGetLinks(
    IncomeFixedCostSetting object) {
  return [];
}

void _incomeFixedCostSettingAttach(
    IsarCollection<dynamic> col, Id id, IncomeFixedCostSetting object) {
  object.id = id;
}

extension IncomeFixedCostSettingQueryWhereSort
    on QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QWhere> {
  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension IncomeFixedCostSettingQueryWhere on QueryBuilder<
    IncomeFixedCostSetting, IncomeFixedCostSetting, QWhereClause> {
  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension IncomeFixedCostSettingQueryFilter on QueryBuilder<
    IncomeFixedCostSetting, IncomeFixedCostSetting, QFilterCondition> {
  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> fixedCostTotalEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fixedCostTotal',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> fixedCostTotalGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fixedCostTotal',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> fixedCostTotalLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fixedCostTotal',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> fixedCostTotalBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fixedCostTotal',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> incomeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'income',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> incomeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'income',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> incomeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'income',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> incomeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'income',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> itemsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'items',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> itemsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'items',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> itemsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'items',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> itemsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'items',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> itemsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'items',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> itemsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'items',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension IncomeFixedCostSettingQueryObject on QueryBuilder<
    IncomeFixedCostSetting, IncomeFixedCostSetting, QFilterCondition> {
  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting,
      QAfterFilterCondition> itemsElement(FilterQuery<IncomeFixedCostItem> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'items');
    });
  }
}

extension IncomeFixedCostSettingQueryLinks on QueryBuilder<
    IncomeFixedCostSetting, IncomeFixedCostSetting, QFilterCondition> {}

extension IncomeFixedCostSettingQuerySortBy
    on QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QSortBy> {
  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      sortByFixedCostTotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fixedCostTotal', Sort.asc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      sortByFixedCostTotalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fixedCostTotal', Sort.desc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      sortByIncome() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'income', Sort.asc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      sortByIncomeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'income', Sort.desc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension IncomeFixedCostSettingQuerySortThenBy on QueryBuilder<
    IncomeFixedCostSetting, IncomeFixedCostSetting, QSortThenBy> {
  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      thenByFixedCostTotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fixedCostTotal', Sort.asc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      thenByFixedCostTotalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fixedCostTotal', Sort.desc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      thenByIncome() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'income', Sort.asc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      thenByIncomeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'income', Sort.desc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension IncomeFixedCostSettingQueryWhereDistinct
    on QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QDistinct> {
  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QDistinct>
      distinctByFixedCostTotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fixedCostTotal');
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QDistinct>
      distinctByIncome() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'income');
    });
  }

  QueryBuilder<IncomeFixedCostSetting, IncomeFixedCostSetting, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension IncomeFixedCostSettingQueryProperty on QueryBuilder<
    IncomeFixedCostSetting, IncomeFixedCostSetting, QQueryProperty> {
  QueryBuilder<IncomeFixedCostSetting, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IncomeFixedCostSetting, int, QQueryOperations>
      fixedCostTotalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fixedCostTotal');
    });
  }

  QueryBuilder<IncomeFixedCostSetting, int, QQueryOperations> incomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'income');
    });
  }

  QueryBuilder<IncomeFixedCostSetting, List<IncomeFixedCostItem>,
      QQueryOperations> itemsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'items');
    });
  }

  QueryBuilder<IncomeFixedCostSetting, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const IncomeFixedCostItemSchema = Schema(
  name: r'IncomeFixedCostItem',
  id: 3595740485011729570,
  properties: {
    r'amount': PropertySchema(
      id: 0,
      name: r'amount',
      type: IsarType.long,
    ),
    r'name': PropertySchema(
      id: 1,
      name: r'name',
      type: IsarType.string,
    )
  },
  estimateSize: _incomeFixedCostItemEstimateSize,
  serialize: _incomeFixedCostItemSerialize,
  deserialize: _incomeFixedCostItemDeserialize,
  deserializeProp: _incomeFixedCostItemDeserializeProp,
);

int _incomeFixedCostItemEstimateSize(
  IncomeFixedCostItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _incomeFixedCostItemSerialize(
  IncomeFixedCostItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.amount);
  writer.writeString(offsets[1], object.name);
}

IncomeFixedCostItem _incomeFixedCostItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IncomeFixedCostItem();
  object.amount = reader.readLong(offsets[0]);
  object.name = reader.readString(offsets[1]);
  return object;
}

P _incomeFixedCostItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension IncomeFixedCostItemQueryFilter on QueryBuilder<IncomeFixedCostItem,
    IncomeFixedCostItem, QFilterCondition> {
  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      amountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'amount',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      amountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'amount',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      amountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'amount',
        value: value,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      amountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'amount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<IncomeFixedCostItem, IncomeFixedCostItem, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }
}

extension IncomeFixedCostItemQueryObject on QueryBuilder<IncomeFixedCostItem,
    IncomeFixedCostItem, QFilterCondition> {}
