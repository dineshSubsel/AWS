public class simpleDML implements IDML {
// Define the interface IDML
public interface IDML {
    void dmlInsert(List<SObject> objList);
    void dmlUpdate(List<SObject> objList);
    void dmlDelete(List<SObject> objList);
    void eventPublish(List<SObject> objList);
}

// Implement the IDML interface in simpleDML class

    public void dmlInsert(List<SObject> objList) {
        insert objList;
    }

    public void dmlUpdate(List<SObject> objList) {
       
        update objList;
    }

    public void dmlDelete(List<SObject> objList) {
        delete objList;
    }

    public void eventPublish(List<SObject> objList) {
        EventBus.publish(objList); 
    }
}