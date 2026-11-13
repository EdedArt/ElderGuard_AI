import Toybox.Lang;

// Who an emergency contact is to the wearer: the keys of contacts.relationship in the web app.
enum Relationship {
    RELATIONSHIP_DAUGHTER,
    RELATIONSHIP_SON,
    RELATIONSHIP_DOCTOR,
}

// Someone the watch would tell when an alert goes out. Treated as immutable, like the readings,
// so alerts can share contacts without copying them.
class Contact {
    var name as String;
    var relationship as Relationship;
    var phone as String;

    function initialize(name as String, relationship as Relationship, phone as String) {
        self.name = name;
        self.relationship = relationship;
        self.phone = phone;
    }
}

// Mirrors src/config/contacts.config.js (ContactsConfig.kt in wear-app). Keep them in sync.
// Fictional people, used only for the demo; the 555-01xx numbers are reserved for fiction. The
// names are data, the same in both languages, as in the other apps.
module ContactsConfig {
    // A new array each call: Monkey C constants cannot hold objects, and a caller that changes
    // the array it gets cannot change anyone else's.
    function contacts() as Array<Contact> {
        return [
            new Contact("Ana Ejemplo", RELATIONSHIP_DAUGHTER, "555-0101"),
            new Contact("Luis Ejemplo", RELATIONSHIP_SON, "555-0102"),
            new Contact("Dra. Prueba", RELATIONSHIP_DOCTOR, "555-0103"),
        ] as Array<Contact>;
    }
}
