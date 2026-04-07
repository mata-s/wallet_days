// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_history.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBudgetHistoryCollection on Isar {
  IsarCollection<BudgetHistory> get budgetHistorys => this.collection();
}

const BudgetHistorySchema = CollectionSchema(
  name: r'BudgetHistory',
  id: 7215359735087831620,
  properties: {
    r'bestStreak': PropertySchema(
      id: 0,
      name: r'bestStreak',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'endDate': PropertySchema(
      id: 2,
      name: r'endDate',
      type: IsarType.dateTime,
    ),
    r'isAchieved': PropertySchema(
      id: 3,
      name: r'isAchieved',
      type: IsarType.bool,
    ),
    r'startDate': PropertySchema(
      id: 4,
      name: r'startDate',
      type: IsarType.dateTime,
    ),
    r'streak': PropertySchema(
      id: 5,
      name: r'streak',
      type: IsarType.long,
    ),
    r'totalBudget': PropertySchema(
      id: 6,
      name: r'totalBudget',
      type: IsarType.long,
    ),
    r'totalExpense': PropertySchema(
      id: 7,
      name: r'totalExpense',
      type: IsarType.long,
    )
  },
  estimateSize: _budgetHistoryEstimateSize,
  serialize: _budgetHistorySerialize,
  deserialize: _budgetHistoryDeserialize,
  deserializeProp: _budgetHistoryDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _budgetHistoryGetId,
  getLinks: _budgetHistoryGetLinks,
  attach: _budgetHistoryAttach,
  version: '3.1.0+1',
);

int _budgetHistoryEstimateSize(
  BudgetHistory object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _budgetHistorySerialize(
  BudgetHistory object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.bestStreak);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeDateTime(offsets[2], object.endDate);
  writer.writeBool(offsets[3], object.isAchieved);
  writer.writeDateTime(offsets[4], object.startDate);
  writer.writeLong(offsets[5], object.streak);
  writer.writeLong(offsets[6], object.totalBudget);
  writer.writeLong(offsets[7], object.totalExpense);
}

BudgetHistory _budgetHistoryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BudgetHistory();
  object.bestStreak = reader.readLong(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.endDate = reader.readDateTime(offsets[2]);
  object.id = id;
  object.isAchieved = reader.readBool(offsets[3]);
  object.startDate = reader.readDateTime(offsets[4]);
  object.streak = reader.readLong(offsets[5]);
  object.totalBudget = reader.readLong(offsets[6]);
  object.totalExpense = reader.readLong(offsets[7]);
  return object;
}

P _budgetHistoryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _budgetHistoryGetId(BudgetHistory object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _budgetHistoryGetLinks(BudgetHistory object) {
  return [];
}

void _budgetHistoryAttach(
    IsarCollection<dynamic> col, Id id, BudgetHistory object) {
  object.id = id;
}

extension BudgetHistoryQueryWhereSort
    on QueryBuilder<BudgetHistory, BudgetHistory, QWhere> {
  QueryBuilder<BudgetHistory, BudgetHistory, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BudgetHistoryQueryWhere
    on QueryBuilder<BudgetHistory, BudgetHistory, QWhereClause> {
  QueryBuilder<BudgetHistory, BudgetHistory, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterWhereClause> idBetween(
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

extension BudgetHistoryQueryFilter
    on QueryBuilder<BudgetHistory, BudgetHistory, QFilterCondition> {
  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      bestStreakEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bestStreak',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      bestStreakGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bestStreak',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      bestStreakLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bestStreak',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      bestStreakBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bestStreak',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      endDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endDate',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      endDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'endDate',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      endDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'endDate',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      endDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'endDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      idGreaterThan(
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

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition> idBetween(
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

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      isAchievedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isAchieved',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      startDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      startDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      startDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      startDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      streakEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'streak',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      streakGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'streak',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      streakLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'streak',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      streakBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'streak',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      totalBudgetEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalBudget',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      totalBudgetGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalBudget',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      totalBudgetLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalBudget',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      totalBudgetBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalBudget',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      totalExpenseEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalExpense',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      totalExpenseGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalExpense',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      totalExpenseLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalExpense',
        value: value,
      ));
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterFilterCondition>
      totalExpenseBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalExpense',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BudgetHistoryQueryObject
    on QueryBuilder<BudgetHistory, BudgetHistory, QFilterCondition> {}

extension BudgetHistoryQueryLinks
    on QueryBuilder<BudgetHistory, BudgetHistory, QFilterCondition> {}

extension BudgetHistoryQuerySortBy
    on QueryBuilder<BudgetHistory, BudgetHistory, QSortBy> {
  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> sortByBestStreak() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bestStreak', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      sortByBestStreakDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bestStreak', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> sortByEndDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> sortByEndDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> sortByIsAchieved() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAchieved', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      sortByIsAchievedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAchieved', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> sortByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      sortByStartDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> sortByStreak() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'streak', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> sortByStreakDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'streak', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> sortByTotalBudget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalBudget', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      sortByTotalBudgetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalBudget', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      sortByTotalExpense() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalExpense', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      sortByTotalExpenseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalExpense', Sort.desc);
    });
  }
}

extension BudgetHistoryQuerySortThenBy
    on QueryBuilder<BudgetHistory, BudgetHistory, QSortThenBy> {
  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByBestStreak() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bestStreak', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      thenByBestStreakDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bestStreak', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByEndDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByEndDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByIsAchieved() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAchieved', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      thenByIsAchievedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAchieved', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      thenByStartDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByStreak() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'streak', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByStreakDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'streak', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy> thenByTotalBudget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalBudget', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      thenByTotalBudgetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalBudget', Sort.desc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      thenByTotalExpense() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalExpense', Sort.asc);
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QAfterSortBy>
      thenByTotalExpenseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalExpense', Sort.desc);
    });
  }
}

extension BudgetHistoryQueryWhereDistinct
    on QueryBuilder<BudgetHistory, BudgetHistory, QDistinct> {
  QueryBuilder<BudgetHistory, BudgetHistory, QDistinct> distinctByBestStreak() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bestStreak');
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QDistinct> distinctByEndDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endDate');
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QDistinct> distinctByIsAchieved() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isAchieved');
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QDistinct> distinctByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startDate');
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QDistinct> distinctByStreak() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'streak');
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QDistinct>
      distinctByTotalBudget() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalBudget');
    });
  }

  QueryBuilder<BudgetHistory, BudgetHistory, QDistinct>
      distinctByTotalExpense() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalExpense');
    });
  }
}

extension BudgetHistoryQueryProperty
    on QueryBuilder<BudgetHistory, BudgetHistory, QQueryProperty> {
  QueryBuilder<BudgetHistory, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BudgetHistory, int, QQueryOperations> bestStreakProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bestStreak');
    });
  }

  QueryBuilder<BudgetHistory, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<BudgetHistory, DateTime, QQueryOperations> endDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endDate');
    });
  }

  QueryBuilder<BudgetHistory, bool, QQueryOperations> isAchievedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isAchieved');
    });
  }

  QueryBuilder<BudgetHistory, DateTime, QQueryOperations> startDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startDate');
    });
  }

  QueryBuilder<BudgetHistory, int, QQueryOperations> streakProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'streak');
    });
  }

  QueryBuilder<BudgetHistory, int, QQueryOperations> totalBudgetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalBudget');
    });
  }

  QueryBuilder<BudgetHistory, int, QQueryOperations> totalExpenseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalExpense');
    });
  }
}
