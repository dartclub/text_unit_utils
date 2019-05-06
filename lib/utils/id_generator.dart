//generate ids from  0 to infinity. Usage only in local main Map<int, ParticleOfSentence>
class Id {
  factory Id() {
    return instance;
  }

  Id._();

  static Id instance = Id._();

  int currentId = 0;

  int currentGroupId = 0;

  int generateId() {
    return currentId++;
  }

  int generateGroupId() {
    return currentGroupId++;
  }
}
